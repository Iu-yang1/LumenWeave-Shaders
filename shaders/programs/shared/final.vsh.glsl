#version 330 compatibility
#include "/lib/quality.glsl"
out vec2 texCoord;
#ifdef SOLAR_GLARE
flat out vec4 lwSolar;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform bool hasSkylight;
uniform int isEyeInWater;
uniform float lwRain;
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_GLARE_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_GLARE_SOURCE colortex0
#endif
vec4 solarVisibility(){
#if defined(LW_DIMENSION_NETHER) || defined(LW_DIMENSION_END)
    return vec4(0.0);
#else
    vec3 dir=normalize(sunPosition);
    float elevation=(mat3(gbufferModelViewInverse)*dir).y;
    if(!hasSkylight || isEyeInWater!=0 || dir.z>=-0.02 || elevation<=0.0) return vec4(0.0);
    vec4 p=gbufferProjection*vec4(dir,0.0);
    if(p.w<=0.0) return vec4(0.0);
    vec2 uv=p.xy/p.w*0.5+0.5;
    if(any(lessThan(uv,vec2(0.0)))||any(greaterThan(uv,vec2(1.0)))) return vec4(0.0);
    vec2 pixel=1.0/vec2(textureSize(depthtex0,0));
    float visible=0.0, light=0.0;
    for(int y=-1;y<=1;++y)for(int x=-1;x<=1;++x) {
        vec2 sampleUv=uv+vec2(x,y)*pixel*3.0;
        if(any(lessThan(sampleUv,vec2(0.0)))||any(greaterThan(sampleUv,vec2(1.0)))) continue;
        float openSky=step(0.999999,textureLod(depthtex0,sampleUv,0.0).r);
#ifdef DISTANT_HORIZONS
        openSky*=step(0.999999,textureLod(dhDepthTex0,sampleUv,0.0).r);
#endif
        visible+=openSky;
        light+=openSky*dot(textureLod(LW_GLARE_SOURCE,sampleUv,0.0).rgb,vec3(0.2126,0.7152,0.0722));
    }
    float intensity=visible/9.0*smoothstep(0.9,4.0,light/max(visible,1.0))*pow(1.0-lwRain,2.0)*smoothstep(0.0,0.08,elevation);
    return vec4(uv,intensity,elevation);
#endif
}
#endif
void main(){
    gl_Position=ftransform();
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
#ifdef SOLAR_GLARE
    lwSolar=solarVisibility();
#endif
}
