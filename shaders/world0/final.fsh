#version 330 compatibility

#define EXPOSURE 0 // [-2 -1 0 1 2]
//#define SHOW_COLOR_CHART

#include "/lib/color/scene.glsl"
#include "/lib/quality.glsl"
#ifdef SPATIAL_AA
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
#ifdef SPATIAL_AA
    scene = spatialAntialias(colortex0, texCoord, scene, float(EXPOSURE));
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
    outputColor = vec4(displayColor(scene, float(EXPOSURE)), 1.0);
}
