#ifndef LW_ACTIVE_TILES
#define LW_ACTIVE_TILES
#include "/lib/voxel/settings.glsl"
layout(std430,binding=0) buffer LwActiveTiles {
    uint count1; uint y1; uint z1; uint pad1;
    uint count2; uint y2; uint z2; uint pad2;
    uint count3; uint y3; uint z3; uint pad3;
    uint tasks1[32768]; uint tasks2[32768]; uint tasks3[32768];
};
ivec3 activeTile(int radius) {
    uint index=radius==1 ? tasks1[gl_WorkGroupID.x] : (radius==2 ? tasks2[gl_WorkGroupID.x] : tasks3[gl_WorkGroupID.x]);
    uint n=uint(VOXEL_GRID_SIZE/4);
    return ivec3(index%n,(index/n)%n,index/(n*n));
}
#endif
