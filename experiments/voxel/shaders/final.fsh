#version 430 compatibility

uniform sampler2D colortex0;
uniform sampler3D lwSecondSampler;
layout(std430, binding = 0) readonly buffer ProbeStatus {
    uint signature;
};

in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

void main() {
    outputColor = texture(colortex0, texCoord);
    if (texCoord.y <= 0.9) {
        return;
    }
    ivec3 center = textureSize(lwSecondSampler, 0) / 2;
    vec4 mixed = texelFetch(lwSecondSampler, center - ivec3(8, 0, 0), 0);
    vec4 occluded = texelFetch(lwSecondSampler, center + ivec3(1, 0, 0), 0);
    bool pass = signature == 0x4c575630u &&
        all(lessThan(abs(mixed - vec4(0.5625, 0.0, 0.5625, 0.0)), vec4(0.001))) &&
        all(lessThan(abs(occluded), vec4(0.001)));
    outputColor = pass ? vec4(0.0, 1.0, 0.0, 1.0) : vec4(1.0, 0.0, 0.0, 1.0);
}
