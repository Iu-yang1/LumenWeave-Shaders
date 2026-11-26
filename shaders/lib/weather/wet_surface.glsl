#ifndef LW_WET_SURFACE
#define LW_WET_SURFACE
#include "/lib/weather/ripples.glsl"
#if RAIN_RIPPLES > 0
uniform float lwWeatherTime;
#endif
// Water-film response; preserve metal and emissive material identity.
uniform float wetness;
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif
#include "/lib/weather/column_height.glsl"
float wetHash(vec2 p) {
    vec3 q=fract(vec3(p.xyx)*0.1031);
    q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float wetNoise(vec2 p) {
    vec2 i=floor(p), t=fract(p);t=t*t*(3.0-2.0*t);
    return mix(mix(wetHash(i),wetHash(i+vec2(1,0)),t.x),
        mix(wetHash(i+vec2(0,1)),wetHash(i+1.0),t.x),t.y);
}
vec2 wetWorldXZ(vec3 viewPosition) {
    return (worldDirection(viewPosition)+vec3(cameraPositionInt)+cameraPositionFract).xz;
}
vec2 wetFilmAndPuddle(vec3 normal,vec2 lightLevels,vec3 viewPosition) {
    if(!hasSkylight || wetness<=0.001) return vec2(0.0);
    vec3 geometry=rainGeometry(viewPosition,normal);
    float exposed=smoothstep(0.80,0.99,lightLevels.y)*geometry.x;
    float film=wetness*exposed*(0.25+0.75*smoothstep(-0.1,0.85,normal.y));
    if(film<=0.001 || normal.y<0.91) return vec2(film,0.0);
    float noise=smoothstep(0.46,0.72,wetNoise(wetWorldXZ(viewPosition)*0.23));
    float basin=mix(noise,mix(noise*0.25,1.0,geometry.y)*geometry.y,geometry.z);
    float puddle=film*film*smoothstep(0.91,0.995,normal.y)*basin*PUDDLE_STRENGTH;
    return vec2(film,puddle);
}
float wetPuddle(vec3 normal,vec2 lightLevels,vec3 viewPosition) {
    return wetFilmAndPuddle(normal,lightLevels,viewPosition).y;
}
vec3 wetRippleNormalFromResponse(vec3 normal,vec3 viewPosition,Material material,vec2 response) {
#if RAIN_RIPPLES > 0
    if(rainStrength<=0.001 || material.metallic>0.5 || material.roughness<0.18 || normal.y<0.91 ||
        max(material.emission.r,max(material.emission.g,material.emission.b))>0.001) return normal;
    float puddle=response.y*smoothstep(0.18,0.45,material.roughness);
    if(puddle>0.001) {
        float footprint=length(viewPosition)*0.002;
        vec2 ripple=rainRippleSlope(wetWorldXZ(viewPosition),lwWeatherTime,footprint);
        return normalize(normal-vec3(ripple.x,0.0,ripple.y)*(rainStrength*puddle));
    }
#endif
    return normal;
}
vec3 wetRippleNormal(vec3 normal,vec2 lightLevels,vec3 viewPosition,Material material) {
    return wetRippleNormalFromResponse(normal,viewPosition,material,wetFilmAndPuddle(normal,lightLevels,viewPosition));
}
void wetSurfaceFromResponse(inout vec3 albedo,inout Material material,vec2 response) {
    if(!hasSkylight || wetness<=0.001 || material.metallic>0.5 || max(material.emission.r,max(material.emission.g,material.emission.b))>0.001) return;
    float film=response.x;
    if(film<=0.001) return;
    float puddle=response.y;
    // Porous matte surfaces darken more, while glass-like smooth dielectrics
    // retain their albedo and do not become a second mirror everywhere.
    float porous=smoothstep(0.45,0.95,material.roughness);
    albedo*=1.0-film*mix(0.07,0.29,porous);
    puddle*=smoothstep(0.18,0.45,material.roughness);
    material.roughness=mix(material.roughness,min(material.roughness,0.38),film);
    material.roughness=mix(material.roughness,min(material.roughness,0.10),puddle);
}

void wetSurface(inout vec3 albedo,inout Material material,vec3 normal,vec2 lightLevels,vec3 viewPosition) {
    wetSurfaceFromResponse(albedo,material,wetFilmAndPuddle(normal,lightLevels,viewPosition));
}

#endif
