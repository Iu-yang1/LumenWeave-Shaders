#version 330 compatibility

out vec3 viewPosition;
out vec4 vertexColor;

void main() {
    gl_Position = ftransform();
    viewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vertexColor = gl_Color;
}
