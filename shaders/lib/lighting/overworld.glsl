#include "/lib/color/scene.glsl"

const float LW_PI = 3.14159265;
const float sunPathRotation = -30.0;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
#include "/lib/weather/state.glsl"
#define rainStrength lwRain
uniform bool hasSkylight;
uniform bool hasCeiling;
uniform float ambientLight;
uniform vec3 fogColor;
#ifdef CAT_THE_END
uniform int biome_category;
#endif

// Sky-light capability is not a dimension identity (modern End has sky light).
bool lwEndDimension() {
#ifdef LW_DIMENSION_END
    return true;
#elif defined(LW_DIMENSION_NETHER)
    return false;
#elif defined(CAT_THE_END)
    return biome_category == CAT_THE_END || (!hasSkylight && !hasCeiling);
#else
    return !hasSkylight && !hasCeiling;
#endif
}
bool lwHasCelestial() {
#if defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)
    return false;
#else
    return hasSkylight && !lwEndDimension();
#endif
}
// Existing lighting users mean celestial sky, not the vanilla light-map flag.
#define hasSkylight lwHasCelestial()

#include "/lib/dimensions/overworld.glsl"
#include "/lib/dimensions/nether.glsl"
#include "/lib/dimensions/end.glsl"
#ifdef LW_DIMENSION_END
#include "/lib/dimensions/end_nebula.glsl"
#endif
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
#include "/lib/atmosphere/physical_lookup.glsl"
uniform sampler2D lwAtmoSky;
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif
#endif

vec3 worldDirection(vec3 viewDirection) {
    return mat3(gbufferModelViewInverse) * viewDirection;
}

#ifdef LW_FRAME_LIGHTING_VERTEX
flat out vec3 lwFrameSun;
flat out vec3 lwFrameDirect;
flat out vec2 lwFrameWeights;
#elif defined(LW_FRAME_LIGHTING_FRAGMENT)
flat in vec3 lwFrameSun;
flat in vec3 lwFrameDirect;
flat in vec2 lwFrameWeights;
#endif

vec3 sunDirection() {
#ifdef LW_FRAME_LIGHTING_FRAGMENT
    return lwFrameSun;
#else
    if (!hasSkylight) {
        return vec3(0.0, 1.0, 0.0);
    }
    return normalize(worldDirection(sunPosition));
#endif
}

float daylight(vec3 sun) {
#ifdef LW_FRAME_LIGHTING_FRAGMENT
    return lwFrameWeights.x;
#else
    return hasSkylight ? smoothstep(-0.16, 0.18, sun.y) : 0.0;
#endif
}

vec3 sunTint(vec3 sun) {
    return mix(vec3(1.0, 0.48, 0.24), vec3(1.0, 0.97, 0.91), smoothstep(0.0, 0.48, sun.y));
}

vec3 celestialIrradiance(vec3 sun) {
#ifdef LW_FRAME_LIGHTING_FRAGMENT
    return lwFrameDirect;
#else
    if (!hasSkylight) {
        return vec3(0.0);
    }
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    if(sun.y>=0.0) {
        float radius=atmoRadius(float(cameraPositionInt.y)+cameraPositionFract.y);
        return atmoSolar(radius,sun.y)*(5.4*SUNLIGHT_STRENGTH);
    }
#endif
    return (sun.y >= 0.0 ? sunTint(sun) * 5.4 : vec3(0.095, 0.13, 0.20)) * SUNLIGHT_STRENGTH;
#endif
}

float celestialVisibility(vec3 sun) {
#ifdef LW_FRAME_LIGHTING_FRAGMENT
    return lwFrameWeights.y;
#else
    return hasSkylight ? smoothstep(0.0, 0.18, abs(sun.y)) * mix(1.0, 0.19, rainStrength) : 0.0;
#endif
}

float dimensionFogDensity(vec3 direction) {
    float horizon = 1.0 - smoothstep(0.05, 0.70, abs(direction.y));
    return hasCeiling ? mix(0.012, 0.027, horizon)
                      : mix(0.0035, 0.010, horizon);
}

vec3 skyRadiance(vec3 direction, vec3 sun) {
    if (!hasSkylight) {
        vec3 fog = decodeSrgb(fogColor);
        if (hasCeiling) {
            // Preserve biome identity, with a warmer lower horizon and darker ceiling.
            float lower = 1.0-smoothstep(-0.25,0.65,direction.y);
            return mix(fog,vec3(0.14,0.032,0.012),0.10+0.13*lower)*mix(0.68,1.0,lower);
        }
        vec3 horizon = vec3(0.010,0.0038,0.022);
        vec3 zenith = vec3(0.0009,0.00055,0.0030);
        return mix(horizon,zenith,smoothstep(0.0,0.85,abs(direction.y)));
    }
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    // In daylight the physical LUT has unit blend weight. Do not calculate
    // analytic Rayleigh/twilight terms which would be discarded.
    if(sun.y>=0.05) {
        vec2 uv=atmoViewUV(direction,sun);
        vec3 physical=texture(lwAtmoSky,atmoTexelUV(uv,textureSize(lwAtmoSky,0))).rgb*(5.4*SUNLIGHT_STRENGTH);
        return mix(physical,mix(vec3(0.024),vec3(0.45,0.51,0.57),daylight(sun)),rainStrength*0.83);
    }
#endif
    float height = max(direction.y, 0.0);
    float cosine = max(dot(direction, sun), 0.0);
    float twilight = 1.0 - smoothstep(0.06, 0.36, abs(sun.y));
    float day = daylight(sun);
    vec3 horizon = mix(vec3(0.020, 0.029, 0.050), vec3(0.61, 0.75, 0.94), day);
    vec3 zenith = mix(vec3(0.003, 0.006, 0.018), vec3(0.10, 0.25, 0.57), day);
#ifdef LITE_LIGHTING
    float skyGradient = (3.2 * height) / (1.0 + 2.35 * height);
#else
    float skyGradient = 1.0 - exp(-3.2 * height);
#endif
    vec3 color = mix(horizon, zenith, skyGradient);
    color += vec3(0.56, 0.19, 0.05) * twilight * pow(cosine, 5.0) * exp(-5.0 * height);
    // Low-frequency night-sky band; stars are rendered in the sky pass.
    if (day < 1.0) {
        float band = 1.0 - smoothstep(0.0, 0.24, abs(dot(direction, normalize(vec3(0.36, 0.48, 0.80)))));
        color += vec3(0.010, 0.012, 0.022) * band * band * height * (1.0 - day);
    }
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    float physicalWeight=smoothstep(-0.15,0.05,sun.y);
    if(physicalWeight>0.0) {
        vec2 uv=atmoViewUV(direction,sun);
        vec3 physical=texture(lwAtmoSky,atmoTexelUV(uv,textureSize(lwAtmoSky,0))).rgb*(5.4*SUNLIGHT_STRENGTH);
        color=mix(color,physical,physicalWeight);
    }
#endif
    color = mix(color, mix(vec3(0.024), vec3(0.45, 0.51, 0.57), day), rainStrength * 0.83);
    return color;
}

// Keep dim light dim, but give level-15 emitters HDR headroom.
vec3 blockLightIrradiance(float level) {
    float x = clamp(level, 0.0, 1.0);
    return x*x*(0.20 + 1.60*x) * vec3(1.0, 0.82, 0.62) * BLOCKLIGHT_STRENGTH;
}

float ambientFloor() {
    return (hasSkylight ? 0.010 : 0.008) * DARK_AMBIENT * AMBIENT_STRENGTH;
}

// Real SH Y00 and Y10 evaluated in a folded coefficient representation.
// For the existing affine, axisymmetric diffuse lobe, l<=1 is exact:
// c00*Y00+c10*Y10 = constant + up*slope. No per-pixel quadrature.
vec3 diffuseSH1(vec3 amplitude,float constantTerm,float verticalTerm,float up){
    return amplitude*(constantTerm+verticalTerm*up);
}
vec3 ambientIrradiance(vec2 light, float up, vec3 sun) {
    float sky = light.y * light.y * mix(DARK_AMBIENT,1.0,light.y);
    if (!hasSkylight) {
#if DIFFUSE_SH == 1
        vec3 environment=hasCeiling ?
            diffuseSH1(mix(vec3(0.038,0.022,0.016),vec3(0.14,0.085,0.06),clamp(ambientLight*8.0,0.0,1.0))*NETHER_AMBIENT,0.775,0.225,up):
            diffuseSH1(vec3(0.075,0.065,0.115)*END_AMBIENT,0.775,0.225,up);
#else
        vec3 environment = hasCeiling ? netherEnvironment(up) : endEnvironment(up);
#endif
        return vec3(ambientFloor()) + environment * (hasCeiling ? 0.48 : 0.38) * DARK_AMBIENT * AMBIENT_STRENGTH
            + blockLightIrradiance(light.x);
    }
    float day=daylight(sun);
#if DIFFUSE_SH == 1
    vec3 amplitude=mix(vec3(0.037,0.045,0.067),vec3(0.19,0.25,0.34),day)*mix(1.0,1.20,rainStrength*day);
    vec3 hemisphere=diffuseSH1(amplitude,0.62,0.38,up);
#else
    vec3 hemisphere=overworldEnvironment(up,day);
#endif
    hemisphere = mix(hemisphere, mix(vec3(0.025,0.031,0.041),vec3(0.30,0.34,0.39),day),rainStrength*0.62);
    return vec3(ambientFloor()) + sky * hemisphere * 0.82 * AMBIENT_STRENGTH
        + blockLightIrradiance(light.x);
}
