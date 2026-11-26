#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/dimensions/celestial_sky.glsl"
uniform sampler2D gtexture;
uniform int renderStage;
uniform int isEyeInWater;
in vec2 texCoord;
in vec4 vertexColor;
in vec3 viewPosition;
/* RENDERTARGETS: 0 */
void main() {
    if (renderStage == MC_RENDER_STAGE_SUN) discard;
    vec3 direction=normalize(worldDirection(viewPosition));
    vec3 sun=sunDirection();
    if (!hasSkylight && !hasCeiling) {
        vec3 color=skyRadiance(direction,sun);
        if(isEyeInWater==0 || isEyeInWater==1) color+=endSkyDetail(direction);
        else color=decodeSrgb(fogColor);
        gl_FragData[0]=vec4(color,1.0);
        return;
    }
    vec4 base=texture(gtexture,texCoord)*vertexColor;
    if(base.a<=0.0) discard;
    vec3 color=decodeSrgb(base.rgb);
    if(renderStage==MC_RENDER_STAGE_MOON)
        color*=vec3(1.15,1.34,1.65)*1.6;
    gl_FragData[0]=vec4(color,base.a);
}
