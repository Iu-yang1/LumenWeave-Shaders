#version 330 compatibility
#include "/lib/quality.glsl"
in vec2 texCoord;
layout(location=0) out vec4 outputColor;
#if DOF_FILTER == 2 && defined(LW_DOF_HALF)
/* RENDERTARGETS: 10 */
/*
const int colortex10Format = RGBA16F;
*/
uniform sampler2D colortex10;
#include "/lib/post/dof.glsl"
void main(){
    ivec2 size=textureSize(colortex10,0);
    ivec2 p=clamp(ivec2(gl_FragCoord.xy),ivec2(0),size-1);
    vec4 center=texelFetch(colortex10,p,0);
    outputColor=vec4(lwDofAxisGather(colortex10,texCoord,center,lwFocusDepth(),vec2(0,1),true),center.a);
}
#else
/* RENDERTARGETS: 0 */
uniform sampler2D colortex0;
void main(){outputColor=texture(colortex0,texCoord);}
#endif
