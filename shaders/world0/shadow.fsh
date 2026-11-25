#version 330 compatibility

#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"

#ifdef LW_VOXEL_ACTIVE
const float voxelDistance = 28.0;
#endif

uniform sampler2D gtexture;
in vec2 texCoord;
in vec4 vertexColor;

/* RENDERTARGETS: 0 */

void main() {
    gl_FragData[0] = texture(gtexture, texCoord) * vertexColor;
}
