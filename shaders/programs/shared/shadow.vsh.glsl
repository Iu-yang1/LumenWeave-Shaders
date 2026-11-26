
#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"

#ifdef LW_VOXEL_ACTIVE
#extension GL_ARB_shader_image_load_store : require
#include "/lib/voxel/inject.glsl"
#endif

#if defined(WAVING_LEAVES) || defined(WAVING_GRASS)
#include "/lib/vegetation/wind.glsl"
uniform vec3 cameraPosition;
in vec2 mc_midTexCoord;
#ifndef LW_VOXEL_ACTIVE
in vec4 at_midBlock;
in vec4 mc_Entity;
uniform mat4 shadowModelViewInverse;
#endif
#endif

uniform bool hasSkylight;

out vec2 texCoord;
out vec4 vertexColor;

void main() {
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
#ifdef LW_VOXEL_ACTIVE
    // Off-screen emitters and occluders still populate the light field.
    injectTerrainVoxel(position.xyz);
#endif
    // No celestial shadow consumer in Nether/End or a voxel-only profile.
    // Keep vertex-side injection but clip before wind and rasterization.
#ifdef SCENE_SHADOWS
#if defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)
    if (true) {
#else
    if (!hasSkylight) {
#endif
#endif
        gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
        texCoord = vec2(0.0);
        vertexColor = vec4(0.0);
        return;
#ifdef SCENE_SHADOWS
    }
#endif
#if defined(WAVING_LEAVES) || defined(WAVING_GRASS)
    int vegetationId = int(mc_Entity.x);
    if (vegetationId >= 10030 && vegetationId <= 10033) {
        vec3 relative = (shadowModelViewInverse * position).xyz;
        vec3 world = relative + cameraPosition;
        vec2 stem = (world + at_midBlock.xyz / 64.0).xz;
        float tip = gl_MultiTexCoord0.y < mc_midTexCoord.y ? 1.0 : 0.0;
        vec3 displacement = vegetationDisplacement(world, stem, vegetationId, tip, length(relative));
        position.xyz += transpose(mat3(shadowModelViewInverse)) * displacement;
    }
#endif
    gl_Position = gl_ProjectionMatrix * position;
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
}
