#version 330 compatibility
#include "/lib/quality.glsl"
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_DOF_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_DOF_SOURCE colortex0
#ifdef LW_STATIC_HDR_REUSE
uniform sampler2D colortex4;
flat in int lwPostHistory;
#endif
#endif
in vec2 texCoord;
layout(location=0) out vec4 outputColor;
#ifdef LW_DOF_HALF
/* RENDERTARGETS: 10 */
/*
const int colortex10Format = RGBA16F;
*/
#if DOF_FILTER == 1
#define LW_DOF_MIP_ASSIST
#ifdef LW_TAA_DIRECT
const bool colortex4MipmapEnabled = true;
#else
const bool colortex0MipmapEnabled = true;
#endif
#endif
#include "/lib/post/dof.glsl"
void lwDofPass(sampler2D source){
    float focus=lwFocusDepth();
    float d=lwDofDepth(texCoord), coc=lwCoC(d,focus);
    vec3 center=texture(source,texCoord).rgb;
#if DOF_FILTER == 2
    outputColor=vec4(lwDofAxisGather(source,texCoord,vec4(center,d),focus,vec2(1,0),false),d);
#else
    outputColor=vec4(lwDofGather(source,texCoord,center,d,coc,focus),d);
#endif
}
void main(){
#ifdef LW_STATIC_HDR_REUSE
    if(lwPostHistory!=0) lwDofPass(colortex4);
    else
#endif
    lwDofPass(LW_DOF_SOURCE);
}
#else
/* RENDERTARGETS: 0 */
void main(){
#ifdef LW_STATIC_HDR_REUSE
    if(lwPostHistory!=0) { outputColor=vec4(texture(colortex4,texCoord).rgb,1.0); return; }
#endif
    outputColor=texture(LW_DOF_SOURCE,texCoord);
}
#endif
