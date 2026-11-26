#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_viewport.glsl"

#ifdef LW_TAA_ACTIVE
#include "/lib/temporal/jitter.glsl"
#endif

out vec3 viewPosition;
out vec3 viewNormal;
out vec2 lightLevels;
out vec4 vertexColor;

void main() {
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * position;
#ifdef LW_TAA_ACTIVE
    gl_Position.xy += 2.0 * jitterOffset(frameCounter) * gl_Position.w;
#endif
    gl_Position=lwRasterClip(gl_Position,1);
    viewPosition = position.xyz;
    viewNormal = gl_NormalMatrix * gl_Normal;
    lightLevels = clamp((gl_MultiTexCoord2.xy * 16.0 - vec2(0.5)) / 15.0, 0.0, 1.0);
    vertexColor = gl_Color;
}
