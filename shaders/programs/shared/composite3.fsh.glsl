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
#else
/* RENDERTARGETS: 0 */
#endif

void main() {
    vec2 texel = 1.0 / vec2(textureSize(colortex0, 0));
    vec3 result = vec3(0.0);
    float threshold = BLOOM_THRESHOLD * exp2(-float(EXPOSURE));
    for (int row = -1; row <= 1; ++row) {
        for (int column = -1; column <= 1; ++column) {
            vec2 uv = clamp(texCoord + vec2(column, row) * texel * 2.0, texel * 0.5, 1.0 - texel * 0.5);
            vec3 sampleColor = texture(colortex0, uv).rgb;
            // Saturated orange/red emitters need not have a high photopic luma.
            float brightness=max(luminance(sampleColor),0.50*max(sampleColor.r,max(sampleColor.g,sampleColor.b)));
            float contribution = smoothstep(threshold * 0.6, threshold * 1.4, brightness);
            result += sampleColor * contribution;
        }
    }
    outputColor = vec4(result / 9.0, 1.0);
}
