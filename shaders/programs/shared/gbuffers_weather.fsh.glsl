#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/fog.glsl"
uniform sampler2D gtexture;
in vec2 texCoord;
in vec2 lightLevels;
in vec4 vertexColor;
in vec3 viewPosition;
/* RENDERTARGETS: 0 */
layout(location=0) out vec4 outputColor;
void main(){
    vec4 base=texture(gtexture,texCoord)*vertexColor;
    vec3 radiance=decodeSrgb(base.rgb)*ambientIrradiance(lightLevels,0.35,sunDirection());
    float transition=smoothstep(0.0,0.30,rainStrength);
    outputColor=vec4(applySceneFog(radiance,viewPosition),base.a*transition);
}
