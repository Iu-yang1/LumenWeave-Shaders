#version 330 compatibility
in vec2 uv;
uniform sampler2D colortex4;
layout(location=0) out vec4 color;
void main(){color=vec4(texture(colortex4,uv).rgb,1.0);}
