#version 330 compatibility
#include "/lib/quality.glsl"
#ifdef LW_SCENE_TAAU
#include "/lib/temporal/scene_grid.glsl"
uniform float viewWidth;
uniform float viewHeight;
#endif
out vec2 texCoord;
void main(){
    gl_Position=ftransform();
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
#ifdef LW_SCENE_TAAU
    ivec2 size=max(ivec2(viewWidth,viewHeight),ivec2(1));
    vec2 scale=vec2(lwSceneRenderSize(size))/vec2(size);
    gl_Position.xy=gl_Position.xy*scale+(scale-1.0)*gl_Position.w;
#endif
}
