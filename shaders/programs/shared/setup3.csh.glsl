#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
// Iris 1.21.1 setup calls dispatch(1,1), even after resize.
// Fixed groups plus a strided loop initialize the actual image extent.
const ivec3 workGroups = ivec3(32,32,1);
#ifdef LW_VOLUME_TEMPORAL_ACTIVE
layout(rgba16f) writeonly uniform image2D lwVolumeHistory;
void main() {
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    ivec2 size=imageSize(lwVolumeHistory);
    ivec2 stride=ivec2(gl_NumWorkGroups.xy*gl_WorkGroupSize.xy);
    for(int y=p.y;y<size.y;y+=stride.y)
        for(int x=p.x;x<size.x;x+=stride.x)
            imageStore(lwVolumeHistory,ivec2(x,y),vec4(0.0));
}
#else
void main(){}
#endif
