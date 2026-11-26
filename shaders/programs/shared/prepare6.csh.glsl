#version 430 core
#include "/lib/quality.glsl"
#ifdef LW_VOXEL_SMOOTH_ACTIVE
#include "/lib/voxel/grid.glsl"
#include "/lib/voxel/dispatch.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
layout(rgba16f) uniform image3D lwVoxelFirst;
#ifdef LW_VOXEL_DIFFUSE_SMOOTH
layout(rgba16f) uniform image3D lwVoxelSecond;
#endif
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
layout(r8ui) uniform uimage3D lwVoxelDirtyTiles;
uniform int frameCounter;
uniform float frameTime;
shared ivec4 previous;
shared ivec3 origin;
shared uint occupied;
shared bool skipTile;
shared ivec3 tileMeta;
void main(){
    if(gl_LocalInvocationIndex==0u){
        previous=imageLoad(lwVoxelMeta,ivec2(0));
        origin=voxelCacheOrigin();
        occupied=0u;
        ivec3 tile=ivec3(gl_WorkGroupID);
        int side=LW_GRID_SIZE/4;
        int index=tile.x+side*(tile.y+side*tile.z);
        tileMeta=ivec3(index%LW_GRID_SIZE,(index/LW_GRID_SIZE)%LW_GRID_SIZE,2*LW_GRID_SIZE+index/(LW_GRID_SIZE*LW_GRID_SIZE));
        bool stationary=previous.w==frameCounter-1 && all(equal(cameraPositionInt,previous.xyz));
        skipTile=false;
        if(stationary && (imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r&4u)==0u)
            skipTile=imageLoad(lwVoxelFirst,tileMeta).r==0.0;
    }
    barrier();
    if(skipTile) {
        if(gl_LocalInvocationIndex==0u) imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(0u));
        return;
    }
    ivec3 local=ivec3(gl_GlobalInvocationID);
    ivec3 cell=voxelWrapNear(local+origin);
    ivec3 historyCell=cell+ivec3(0,0,LW_GRID_SIZE);
    ivec3 previousLocal=local+cameraPositionInt-previous.xyz;
    bool valid=previous.w==frameCounter-1 && withinVoxelGrid(previousLocal);
    vec4 target=imageLoad(lwVoxelFirst,cell);
    vec4 old=valid?imageLoad(lwVoxelFirst,historyCell):target;
    float halfLife=dot(target.rgb,vec3(0.2126,0.7152,0.0722))>dot(old.rgb,vec3(0.2126,0.7152,0.0722))?DIRECT_RISE_HALF:DIRECT_FALL_HALF;
    vec4 value=mix(target,old,exp2(-clamp(frameTime,0.0,0.25)/halfLife));
    // New opaque walls must never retain old light. Quantize tiny tails to zero.
    bool wall=imageLoad(lwVoxelOccupancy,local).r>=LW_VOXEL_WALL;
    if(wall) value=vec4(0.0);
    if(max(value.r,max(value.g,value.b))<0.0005) value=vec4(0.0);
    if(!valid || any(notEqual(value,old))) imageStore(lwVoxelFirst,historyCell,value);
    if(max(max(target.r,max(target.g,target.b)),max(value.r,max(value.g,value.b)))>0.0) atomicOr(occupied,1u);
#ifdef LW_VOXEL_DIFFUSE_SMOOTH
    // Raw diffuse propagation remains independent. A separate world-space
    // history follows its own irradiance, including hue changes and removals.
    vec4 diffuseTarget=imageLoad(lwVoxelSecond,cell);
    vec4 diffuseOld=valid?imageLoad(lwVoxelSecond,historyCell):diffuseTarget;
    float diffuseHalf=dot(diffuseTarget.rgb,vec3(0.2126,0.7152,0.0722))>dot(diffuseOld.rgb,vec3(0.2126,0.7152,0.0722))?DIFFUSE_RISE_HALF:DIFFUSE_FALL_HALF;
    vec4 diffuseValue=mix(diffuseTarget,diffuseOld,exp2(-clamp(frameTime,0.0,0.25)/diffuseHalf));
    if(wall) diffuseValue=vec4(0.0);
    if(max(diffuseValue.r,max(diffuseValue.g,diffuseValue.b))<0.0005) diffuseValue=vec4(0.0);
    if(!valid || any(notEqual(diffuseValue,diffuseOld))) imageStore(lwVoxelSecond,historyCell,diffuseValue);
    // Union support ensures the tile cannot be skipped while diffuse tails remain.
    if(max(max(diffuseTarget.r,max(diffuseTarget.g,diffuseTarget.b)),max(diffuseValue.r,max(diffuseValue.g,diffuseValue.b)))>0.0) atomicOr(occupied,2u);
#endif
    barrier();
    // The original dirty seed slab is no longer needed by propagation.
    if(gl_LocalInvocationIndex==0u) {
        imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(occupied));
        imageStore(lwVoxelFirst,tileMeta,vec4(float(occupied),0.0,0.0,0.0));
    }
}
#else
layout(local_size_x=1,local_size_y=1) in;
const ivec3 workGroups=ivec3(1,1,1);
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
layout(rgba32i) writeonly uniform iimage2D lwVoxelMeta;
uniform ivec3 cameraPositionInt;
uniform int frameCounter;
void main(){ imageStore(lwVoxelMeta,ivec2(0),ivec4(cameraPositionInt,frameCounter)); }
#else
void main(){}
#endif
#endif
