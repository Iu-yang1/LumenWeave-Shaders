#version 330 compatibility

#include "/lib/color/scene.glsl"
#include "/lib/quality.glsl"
#include "/lib/post/display.glsl"
#define LW_EXPOSURE_FINAL
#include "/lib/post/exposure.glsl"
#if DOF_MODE != 0
#include "/lib/post/dof.glsl"
const float centerDepthHalflife = 6.0;
#ifdef LW_DOF_HALF
uniform sampler2D colortex10;
#endif
#endif
#ifdef SOLAR_GLARE
#include "/lib/post/solar_glare.glsl"
#endif
#ifdef BLOOM
uniform sampler2D colortex11;
#endif
#ifdef LW_FXAA_ACTIVE
#include "/lib/color/spatial_aa.glsl"
#endif

#ifndef SCENE_SHADOWS
const int shadowMapResolution = 64;
#endif

/*
const int colortex0Format = RGBA16F;
const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
*/

#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_POST_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_POST_SOURCE colortex0
#endif
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

void main() {
    float exposure=float(EXPOSURE)+lwExposureEV();
    vec3 scene = texture(LW_POST_SOURCE, texCoord).rgb;
#ifdef LW_FXAA_ACTIVE
    scene = spatialAntialias(LW_POST_SOURCE, texCoord, scene, exposure);
#endif
    if (IMAGE_SHARPENING > 0.0) {
        scene = sharpenScene(LW_POST_SOURCE, texCoord, scene);
    }
#if DOF_MODE != 0
    float depth=lwDofDepth(texCoord), coc=lwCoC(depth,lwFocusDepth());
    if(depth>0.0) {
#ifdef LW_DOF_HALF
        vec4 blurred=texture(colortex10,texCoord);
        float confidence=1.0-smoothstep(0.04,0.18,abs(blurred.a-depth)/max(depth,0.5));
        scene=confidence>=0.999 ? blurred.rgb : mix(lwDofGather(LW_POST_SOURCE,texCoord,scene,depth,coc),blurred.rgb,confidence);
#else
        scene=lwDofGather(LW_POST_SOURCE,texCoord,scene,depth,coc);
#endif
    }
#endif
#ifdef BLOOM
#if BLOOM_FILTER == 0
    // The quarter-resolution buffer already provides a four-pixel footprint.
    vec3 bloom=texture(colortex11,texCoord).rgb;
#else
    vec2 bloomTexel=1.0/vec2(textureSize(colortex11,0));
    vec3 bloom=vec3(0.0);
#if BLOOM_FILTER == 1
    // Four bilinear samples form a normalized soft footprint, without
    // a second full-resolution blur pass or nine texture queries.
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        vec2 uv=clamp(texCoord+(vec2(x,y)*2.0-1.0)*bloomTexel,
            bloomTexel*0.5,1.0-bloomTexel*0.5);
        bloom+=texture(colortex11,uv).rgb;
    }
    bloom*=0.25;
#else
    for(int y=-1;y<=1;++y) for(int x=-1;x<=1;++x) {
        float weight=float((2-abs(y))*(2-abs(x)));
        vec2 uv=clamp(texCoord+vec2(x,y)*bloomTexel*2.0,
            bloomTexel*0.5,1.0-bloomTexel*0.5);
        bloom+=texture(colortex11,uv).rgb*weight;
    }
    bloom*=1.0/16.0;
#endif
#endif
    scene+=bloom*BLOOM_STRENGTH;
#endif
#ifdef SOLAR_GLARE
    scene+=lwSolarGlare(texCoord,vec2(textureSize(LW_POST_SOURCE,0)));
#endif
#ifdef SHOW_COLOR_CHART
    if (texCoord.y >= 0.90) {
        const vec3 swatches[10] = vec3[10](
            vec3(0.0), vec3(0.01), vec3(0.04), vec3(0.18), vec3(0.50),
            vec3(1.0), vec3(2.0), vec3(4.0), vec3(8.0), vec3(4.0, 0.10, 0.04)
        );
        scene = swatches[clamp(int(texCoord.x * 10.0), 0, 9)];
    }
#endif
    outputColor = vec4(displayColor(gradeRadiance(scene), exposure), 1.0);
}
