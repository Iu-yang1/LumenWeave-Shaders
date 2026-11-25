#version 330 compatibility

#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"

#ifdef LW_VOXEL_ACTIVE
#extension GL_ARB_shader_image_load_store : require
#include "/lib/voxel/inject.glsl"
#endif

out vec2 texCoord;
out vec4 vertexColor;

void main() {
    gl_Position = ftransform();
#ifdef LW_VOXEL_ACTIVE
    injectTerrainVoxel((gl_ModelViewMatrix * gl_Vertex).xyz);
#endif
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
}
