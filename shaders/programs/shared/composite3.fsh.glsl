#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/color/scene.glsl"
uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;
#ifdef BLOOM
/* RENDERTARGETS: 11 */
/*
const int colortex11Format = RGBA16F;
*/
vec3 bloomHighlight(vec2 uv,vec2 texel,float threshold) {
    vec3 sampleColor=texture(colortex0,clamp(uv,texel*0.5,1.0-texel*0.5)).rgb;
    // Hue-preserving HDR extraction, including saturated red/orange emitters.
    float brightness=max(luminance(sampleColor),0.50*max(sampleColor.r,max(sampleColor.g,sampleColor.b)));
    float contribution=smoothstep(threshold*0.6,threshold*1.4,brightness);
    // Extract excess HDR energy, rather than blurring the entire bright
    // surface. Soft threshold retains a continuous halo transition.
    float excess=max(brightness-threshold*0.6,0.0);
    return sampleColor*contribution*min(1.0,excess/max(brightness,0.0001));
}
void main() {
    vec2 texel=1.0/vec2(textureSize(colortex0,0));
    float threshold=BLOOM_THRESHOLD*exp2(-float(EXPOSURE));
    vec3 result=vec3(0.0);
#if BLOOM_FILTER == 2
    for(int y=-1;y<=1;++y) for(int x=-1;x<=1;++x)
        result+=bloomHighlight(texCoord+vec2(x,y)*texel*2.0,texel,threshold);
    result*=1.0/9.0;
#else
    // Four bilinear taps span the 4x4 source footprint at quarter size.
    // Extract per tap so small bright lights survive downsampling.
    for(int y=0;y<2;++y) for(int x=0;x<2;++x)
        result+=bloomHighlight(texCoord+(vec2(x,y)*2.0-1.0)*texel,texel,threshold);
    result*=0.25;
#endif
    outputColor=vec4(result,1.0);
}
#else
/* RENDERTARGETS: 0 */
void main(){outputColor=texture(colortex0,texCoord);}
#endif
