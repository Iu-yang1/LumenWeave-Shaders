#version 330 compatibility
#define LW_DIMENSION_END
#include "/lib/quality.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/dimensions/celestial_sky.glsl"
uniform int isEyeInWater;
in vec3 viewPosition;
/* RENDERTARGETS: 0 */
void main() {
    vec3 d=normalize(worldDirection(viewPosition));
    vec3 color=skyRadiance(d,vec3(0,1,0))+endSkyDetail(d);
    if(isEyeInWater!=0 && isEyeInWater!=1) color=decodeSrgb(fogColor);
    gl_FragData[0]=vec4(color,1.0);
}
