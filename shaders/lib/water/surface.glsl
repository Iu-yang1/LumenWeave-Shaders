#include "/lib/water/waves.glsl"
#include "/lib/water/optics.glsl"
#include "/lib/coordinates/reconstruct.glsl"

uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float frameTime;
uniform sampler2D depthtex1;

float waterThickness(vec3 viewPosition, vec2 screen) {
    ivec2 pixel = depthPixelAtUv(depthtex1,screen);
    float depth = texelFetch(depthtex1,pixel,0).r;
    if (depth >= 1.0) {
        return 48.0;
    }
    vec3 background = reconstructViewPosition(depthPixelUv(depthtex1,pixel),depth);
    return clamp(dot(background - viewPosition, normalize(viewPosition)), 0.0, 48.0);
}

vec3 waveNormal(vec3 normal, vec3 position, float skyAccess) {
    vec2 footprintX = dFdx(position.xz);
    vec2 footprintY = dFdy(position.xz);
    vec2 slope = waterWaveSlope(position.xz, footprintX, footprintY, frameTimeCounter, frameTime);
    float rain=rainStrength*skyAccess*float(hasSkylight);
    slope *= mix(1.0,1.35,rain);
#if RAIN_RIPPLES > 0
    if(rain>0.001) slope+=rainRippleSlope(position.xz,frameTimeCounter,sqrt(max(dot(footprintX,footprintX),dot(footprintY,footprintY))))*rain;
#endif
    slope*=smoothstep(0.65,0.95,abs(normal.y));
    return normalize(normal - vec3(slope.x, 0.0, slope.y) * sign(normal.y));
}

vec3 waterSunGlint(vec3 normal, vec3 view, vec3 sun, float skyAccess) {
    if (!hasSkylight) {
        return vec3(0.0);
    }
    vec3 light = sun.y >= 0.0 ? sun : -sun;
    vec3 halfVector = view + light;
    halfVector *= inversesqrt(max(dot(halfVector, halfVector), 0.00001));
    float normalLight = max(dot(normal, light), 0.0);
    float normalView = max(dot(normal, view), 0.001);
    float normalHalf = max(dot(normal, halfVector), 0.0);
    float variance = dot(dFdx(normal), dFdx(normal)) + dot(dFdy(normal), dFdy(normal));
    float roughnessSquared = WATER_ROUGHNESS * WATER_ROUGHNESS;
    float alphaSquared = clamp(roughnessSquared * roughnessSquared + variance * 0.6, 0.0004, 0.12);
    float denominator = normalHalf * normalHalf * (alphaSquared - 1.0) + 1.0;
    float distribution = alphaSquared / (LW_PI * denominator * denominator);
    float grazing=1.0-max(dot(view,halfVector),0.0);
    float grazing2=grazing*grazing;
    float fresnel=0.0204+0.9796*grazing2*grazing2*grazing;
    float masking = 0.25 / (mix(normalView, 1.0, 0.16) * mix(normalLight, 1.0, 0.16));
    float visibility = smoothstep(0.0, 0.18, abs(sun.y)) * mix(1.0, 0.19, rainStrength);
    return celestialIrradiance(sun) * (distribution * masking * fresnel * normalLight * visibility * skyAccess);
}
