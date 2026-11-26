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
float wetPuddle(vec3 normal,vec2 lightLevels,vec3 viewPosition) {
    if(!hasSkylight || wetness<=0.001 || normal.y<0.91) return 0.0;
    float film=wetness*smoothstep(0.80,0.99,lightLevels.y)*(0.25+0.75*smoothstep(-0.1,0.85,normal.y));
    return film*film*smoothstep(0.91,0.995,normal.y)*smoothstep(0.46,0.72,wetNoise(wetWorldXZ(viewPosition)*0.23))*PUDDLE_STRENGTH;
}
vec3 wetRippleNormal(vec3 normal,vec2 lightLevels,vec3 viewPosition,Material material) {
#if RAIN_RIPPLES > 0
    if(rainStrength<=0.001 || material.metallic>0.5 || material.roughness<0.18 || normal.y<0.91 ||
        max(material.emission.r,max(material.emission.g,material.emission.b))>0.001) return normal;
    float puddle=wetPuddle(normal,lightLevels,viewPosition)*smoothstep(0.18,0.45,material.roughness);
    if(puddle>0.001) {
        float footprint=length(viewPosition)*0.002;
        vec2 ripple=rainRippleSlope(wetWorldXZ(viewPosition),lwWeatherTime,footprint);
        return normalize(normal-vec3(ripple.x,0.0,ripple.y)*(rainStrength*puddle));
    }
#endif
    return normal;
}
void wetSurface(inout vec3 albedo,inout Material material,vec3 normal,vec2 lightLevels,vec3 viewPosition) {
    if(!hasSkylight || wetness<=0.001 || material.metallic>0.5 || max(material.emission.r,max(material.emission.g,material.emission.b))>0.001) return;
    float exposed=smoothstep(0.80,0.99,lightLevels.y);
    float film=wetness*exposed*(0.25+0.75*smoothstep(-0.1,0.85,normal.y));
    if(film<=0.001) return;
    vec2 pos=(worldDirection(viewPosition)+vec3(cameraPositionInt)+cameraPositionFract).xz;
    float basin=smoothstep(0.46,0.72,wetNoise(pos*0.23));
    float puddle=film*film*smoothstep(0.91,0.995,normal.y)*basin*PUDDLE_STRENGTH;
    // Porous matte surfaces darken more, while glass-like smooth dielectrics
    // retain their albedo and do not become a second mirror everywhere.
    float porous=smoothstep(0.45,0.95,material.roughness);
    albedo*=1.0-film*mix(0.07,0.29,porous);
    puddle*=smoothstep(0.18,0.45,material.roughness);
    material.roughness=mix(material.roughness,min(material.roughness,0.38),film);
    material.roughness=mix(material.roughness,min(material.roughness,0.10),puddle);
}

#endif
