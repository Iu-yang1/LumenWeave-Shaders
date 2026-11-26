// Two Jacobi iterations with a two-cell input halo. Groups never read
// each other's output; the intermediate is quantized as RGBA16F.
#include "/lib/voxel/grid.glsl"
#include "/lib/voxel/dirty_tiles.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
#endif
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
#include "/lib/voxel/packed_field.glsl"
#ifdef LW_PAIR_SOURCE_SEED
layout(r16ui) readonly uniform uimage3D LW_VOXEL_READ;
layout(r32ui) writeonly uniform uimage3D LW_VOXEL_WRITE;
vec4 pairRead(ivec3 p) { return lwDecodeSource(imageLoad(LW_VOXEL_READ,p).r); }
void pairWrite(ivec3 p,vec4 value) { imageStore(LW_VOXEL_WRITE,p,uvec4(lwPackStage2(value))); }
#else
layout(r32ui) readonly uniform uimage3D LW_VOXEL_READ;
layout(rgba16f) writeonly uniform image3D LW_VOXEL_WRITE;
vec4 pairRead(ivec3 p) { return lwUnpackStage2(imageLoad(LW_VOXEL_READ,p).r); }
void pairWrite(ivec3 p,vec4 value) { imageStore(LW_VOXEL_WRITE,p,value); }
#endif
shared vec4 pairInput[512];
shared vec4 pairMiddle[216];
shared uint pairSeeds[216];
shared ivec3 pairOrigin;

ivec3 pairCell(int index,int side) {
    return ivec3(index%side,(index/side)%side,index/(side*side));
}
int pairIndex(ivec3 cell,int side) {
    return cell.x+side*(cell.y+side*cell.z);
}
int pairHaloDistance(ivec3 p) {
    ivec3 distance=max(max(-p,p-ivec3(3)),ivec3(0));
    return distance.x+distance.y+distance.z;
}
vec4 pairHalf(vec4 v) {
    return lwFieldHalf(v);
}
vec4 pairPropagate(uint seed,vec4 incoming) {
    if(seed>=LW_VOXEL_WALL) return vec4(0.0);
    vec3 source=seed==0u?vec3(0.0):voxelSeedEmission(seed);
    return vec4(max(source,incoming.rgb*0.73),
                max(float(any(greaterThan(source,vec3(0.0)))),incoming.a-0.20));
}
void main() {
#ifdef LW_GPU_COMPACTION
    ivec3 tile=activeTile(1);
#else
    ivec3 tile=ivec3(gl_WorkGroupID);
#endif
    uint mask=voxelTileMask(tile);
    if((mask&1u)==0u) return;
    ivec3 base=tile*4;
    ivec3 local=ivec3(gl_LocalInvocationID);
    int lane=int(gl_LocalInvocationIndex);
    if(lane==0) pairOrigin=voxelCacheOrigin();
    barrier();
    if((mask&4u)==0u) {
        pairWrite(voxelWrapNear(base+local+pairOrigin),vec4(0.0));
        return;
    }
    for(int i=lane;i<512;i+=64) {
        ivec3 p=pairCell(i,8)-2;
        if(pairHaloDistance(p)>2) continue;
        ivec3 cell=base+p;
        vec4 v=vec4(0.0);
        if(withinVoxelGrid(cell)) v=pairRead(voxelWrapNear(cell+pairOrigin));
        pairInput[i]=v;
    }
    barrier();
    for(int i=lane;i<216;i+=64) {
        ivec3 p=pairCell(i,6);
        if(pairHaloDistance(p-1)>1) continue;
        ivec3 cell=base+p-1;
        uint seed=LW_VOXEL_WALL;
        if(withinVoxelGrid(cell)) seed=imageLoad(lwVoxelOccupancy,cell).r;
        pairSeeds[i]=seed;
        vec4 incoming=vec4(0.0);
        if(seed<LW_VOXEL_WALL) {
            for(int axis=0;axis<6;++axis)
                incoming=max(incoming,pairInput[pairIndex(p+1+LW_VOXEL_DIRECTIONS[axis],8)]);
        }
        pairMiddle[i]=pairHalf(pairPropagate(seed,incoming));
    }
    barrier();
    ivec3 center=local+1;
    uint seed=pairSeeds[pairIndex(center,6)];
    vec4 incoming=vec4(0.0);
    if(seed<LW_VOXEL_WALL) {
        for(int axis=0;axis<6;++axis)
            incoming=max(incoming,pairMiddle[pairIndex(center+LW_VOXEL_DIRECTIONS[axis],6)]);
    }
    pairWrite(voxelWrapNear(base+local+pairOrigin),pairPropagate(seed,incoming));
}
