#include "/lib/quality.glsl"

#if defined(LW_TAA_ACTIVE) && defined(LW_TERRAIN)
#include "/lib/temporal/jitter.glsl"
#endif

out vec2 texCoord;
out vec2 lightLevels;
out vec4 vertexColor;
out vec3 viewPosition;
#ifdef LW_TERRAIN
in vec4 mc_Entity;
out vec3 viewNormal;
flat out int blockId;
#if defined(WAVING_LEAVES) || defined(WAVING_GRASS)
in vec4 at_midBlock;
in vec2 mc_midTexCoord;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
#include "/lib/vegetation/wind.glsl"
#endif
#endif
#if defined(DEFERRED_LIGHTING) && defined(LW_OPAQUE_TERRAIN) && defined(MC_TEXTURE_FORMAT_LAB_PBR_1_3)
in vec4 at_tangent;
out vec4 viewTangent;
#endif

void main() {
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
#if defined(LW_TERRAIN) && (defined(WAVING_LEAVES) || defined(WAVING_GRASS))
    int vegetationId = int(mc_Entity.x);
    if (vegetationId >= 10030 && vegetationId <= 10033) {
        vec3 relative = (gbufferModelViewInverse * position).xyz;
        vec3 world = relative + cameraPosition;
        vec2 stem = (world + at_midBlock.xyz / 64.0).xz;
        float tip = gl_MultiTexCoord0.y < mc_midTexCoord.y ? 1.0 : 0.0;
        vec3 displacement = vegetationDisplacement(world, stem, vegetationId, tip, length(relative));
        position.xyz += transpose(mat3(gbufferModelViewInverse)) * displacement;
    }
#endif
    gl_Position = gl_ProjectionMatrix * position;
#if defined(LW_TAA_ACTIVE) && defined(LW_TERRAIN)
    gl_Position.xy += 2.0 * jitterOffset(frameCounter) * gl_Position.w;
#endif
    viewPosition = position.xyz;
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 lightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lightLevels = clamp((lightCoord * 16.0 - 0.5) / 15.0, 0.0, 1.0);
    vertexColor = gl_Color;
#ifdef LW_TERRAIN
    viewNormal = gl_NormalMatrix * gl_Normal;
    blockId = int(mc_Entity.x);
#endif
#if defined(DEFERRED_LIGHTING) && defined(LW_OPAQUE_TERRAIN) && defined(MC_TEXTURE_FORMAT_LAB_PBR_1_3)
    viewTangent = vec4(gl_NormalMatrix * at_tangent.xyz, at_tangent.w);
#endif
}
