#version 330 compatibility

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

out vec2 texCoord;
out vec4 vertexColor;

void main() {
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
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
#ifdef LW_VOXEL_ACTIVE
    injectTerrainVoxel((gl_ModelViewMatrix * gl_Vertex).xyz);
#endif
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
}
