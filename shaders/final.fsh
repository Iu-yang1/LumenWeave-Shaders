#version 330 compatibility

#define SOFT_COLOR

uniform sampler2D colortex0;

in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

void main() {
    vec4 scene = texture(colortex0, texCoord);

#ifdef SOFT_COLOR
    float luma = dot(scene.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 muted = mix(vec3(luma), scene.rgb, 0.92);
    scene.rgb = mix(vec3(0.5), muted, 0.94);
#endif

    outputColor = scene;
}
