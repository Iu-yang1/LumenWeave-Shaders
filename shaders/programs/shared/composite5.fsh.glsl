#version 330 compatibility
#include "/lib/quality.glsl"
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_DOF_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_DOF_SOURCE colortex0
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
void main(){
    float focus=lwFocusDepth();
    float d=lwDofDepth(texCoord), coc=lwCoC(d,focus);
    vec3 center=texture(LW_DOF_SOURCE,texCoord).rgb;
#if DOF_FILTER == 2
    outputColor=vec4(lwDofAxisGather(LW_DOF_SOURCE,texCoord,vec4(center,d),focus,vec2(1,0),false),d);
#else
    outputColor=vec4(lwDofGather(LW_DOF_SOURCE,texCoord,center,d,coc,focus),d);
#endif
}
#else
/* RENDERTARGETS: 0 */
void main(){outputColor=texture(LW_DOF_SOURCE,texCoord);}
#endif
