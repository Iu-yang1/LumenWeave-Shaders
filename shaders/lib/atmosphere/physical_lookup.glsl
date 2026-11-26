#ifndef LW_PHYSICAL_LOOKUP
#define LW_PHYSICAL_LOOKUP
#include "/lib/atmosphere/physical_common.glsl"
uniform sampler2D lwAtmoTrans;
vec3 atmoSolar(float radius,float mu) {
    float horizon=atmoHorizon(radius);
    if(mu<horizon) return vec3(0.0);
    float u=sqrt(clamp((mu-horizon)/max(1.0-horizon,0.0001),0.0,1.0));
    vec2 uv=vec2(u,atmoAltitudeUv(radius));
    return texture(lwAtmoTrans,atmoTexelUV(uv,textureSize(lwAtmoTrans,0))).rgb;
}
#endif
