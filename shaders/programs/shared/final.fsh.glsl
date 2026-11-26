#version 330 compatibility

#include "/lib/color/scene.glsl"
#include "/lib/quality.glsl"
#include "/lib/post/display.glsl"
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

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

void main() {
    vec3 scene = texture(colortex0, texCoord).rgb;
#ifdef LW_FXAA_ACTIVE
    scene = spatialAntialias(colortex0, texCoord, scene, float(EXPOSURE));
#endif
    if (IMAGE_SHARPENING > 0.0) {
        scene = sharpenScene(colortex0, texCoord, scene);
    }
#ifdef BLOOM
    vec2 bloomTexel = 1.0 / vec2(textureSize(colortex11, 0));
    vec3 bloom = vec3(0.0);
    float bloomWeight = 0.0;
    for (int row = -1; row <= 1; ++row) {
        for (int column = -1; column <= 1; ++column) {
            float weight = float((2 - abs(row)) * (2 - abs(column)));
            vec2 uv = clamp(texCoord + vec2(column, row) * bloomTexel * 2.0,
                bloomTexel * 0.5, 1.0 - bloomTexel * 0.5);
            bloom += texture(colortex11, uv).rgb * weight;
            bloomWeight += weight;
        }
    }
    scene += bloom * (BLOOM_STRENGTH / bloomWeight);
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
    outputColor = vec4(displayColor(gradeRadiance(scene), float(EXPOSURE)), 1.0);
}
