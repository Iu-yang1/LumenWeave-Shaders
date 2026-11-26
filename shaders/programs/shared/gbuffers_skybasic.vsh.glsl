#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_viewport.glsl"
#ifdef LW_GEOMETRY_TAAU
#include "/lib/temporal/jitter.glsl"
#endif

out vec3 viewPosition;
out vec4 vertexColor;

void main() {
    gl_Position = ftransform();
#ifdef LW_GEOMETRY_TAAU
    gl_Position.xy+=2.0*jitterOffset(frameCounter)*gl_Position.w;
    gl_Position=lwRasterClip(gl_Position,1);
#endif
    viewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vertexColor = gl_Color;
}
