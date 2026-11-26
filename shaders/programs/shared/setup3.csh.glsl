#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const vec2 workGroupsRender=vec2(1.5,1.0);
#ifdef LW_VOLUME_TEMPORAL_ACTIVE
layout(rgba16f) writeonly uniform image2D lwVolumeHistory;
void main() {
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    if(all(lessThan(p,imageSize(lwVolumeHistory)))) imageStore(lwVolumeHistory,p,vec4(0));
}
#else
void main(){}
#endif
