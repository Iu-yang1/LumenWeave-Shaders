#version 330 compatibility

#define SOFT_COLOR

#ifdef SOFT_COLOR
#include "/lib/soft_color.glsl"
#endif

uniform sampler2D colortex0;

in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

void main() {
    vec4 scene = texture(colortex0, texCoord);

#ifdef SOFT_COLOR
    scene.rgb = applySoftColor(scene.rgb);
#endif

    outputColor = scene;
}
