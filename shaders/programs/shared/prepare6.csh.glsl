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
shared uint transitioning;
shared uint previousSupport;
shared bool skipTile;
shared ivec3 tileMeta;
shared vec2 directDecay;
#ifdef LW_VOXEL_DIFFUSE_SMOOTH
shared vec2 diffuseDecay;
#endif
vec4 settleHistory(vec4 value,vec4 target,vec4 old,bool wall,out bool pending){
    if(wall) { pending=false;return vec4(0.0); }
    if(all(equal(old,target))) { pending=false;return target; }
    // Compare representable half-float values; snap a sub-quantum tail
    // so a converged tile cannot remain active indefinitely.
    vec4 tolerance=max(abs(target)*0.0015,vec4(0.0005));
    bvec4 close=lessThanEqual(abs(value-target),tolerance);
    value=mix(value,target,close);
    vec4 quantized=vec4(unpackHalf2x16(packHalf2x16(value.xy)),unpackHalf2x16(packHalf2x16(value.zw)));
    if(all(equal(quantized,old))) quantized=target;
    pending=any(notEqual(quantized,target));
    return quantized;
}
void main(){
    if(gl_LocalInvocationIndex==0u){
        previous=imageLoad(lwVoxelMeta,ivec2(0));
        origin=voxelCacheOrigin();
        occupied=0u;
        transitioning=0u;
        ivec3 tile=ivec3(gl_WorkGroupID);
        int side=LW_GRID_SIZE/4;
        int index=tile.x+side*(tile.y+side*tile.z);
        tileMeta=ivec3(index%LW_GRID_SIZE,(index/LW_GRID_SIZE)%LW_GRID_SIZE,2*LW_GRID_SIZE+index/(LW_GRID_SIZE*LW_GRID_SIZE));
        bool stationary=previous.w==frameCounter-1 && all(equal(cameraPositionInt,previous.xyz));
        skipTile=false;
        vec4 prior=imageLoad(lwVoxelFirst,tileMeta);
        previousSupport=uint(prior.r);
        uint mask=imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r;
        // Only skip on an unchanged world-local tile with a settled history.
        // Dirty radius-two covers both direct and diffuse target changes.
        if(stationary && (mask&3u)==0u && prior.g==0.0)
            skipTile=true;
        if(!skipTile){
            float dt=clamp(frameTime,0.0,0.25);
            directDecay=exp2(-dt/vec2(DIRECT_RISE_HALF,DIRECT_FALL_HALF));
#ifdef LW_VOXEL_DIFFUSE_SMOOTH
            diffuseDecay=exp2(-dt/vec2(DIFFUSE_RISE_HALF,DIFFUSE_FALL_HALF));
#endif
        }
    }
    barrier();
    if(skipTile) {
        if(gl_LocalInvocationIndex==0u) imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(previousSupport));
        return;
    }
    ivec3 local=ivec3(gl_GlobalInvocationID);
    ivec3 cell=voxelWrapNear(local+origin);
    ivec3 historyCell=cell+ivec3(0,0,LW_GRID_SIZE);
    ivec3 previousLocal=local+cameraPositionInt-previous.xyz;
    bool valid=previous.w==frameCounter-1 && withinVoxelGrid(previousLocal);
    vec4 target=imageLoad(lwVoxelFirst,cell);
    vec4 old=valid?imageLoad(lwVoxelFirst,historyCell):target;
    float decay=dot(target.rgb,vec3(0.2126,0.7152,0.0722))>dot(old.rgb,vec3(0.2126,0.7152,0.0722))?directDecay.x:directDecay.y;
    vec4 value=mix(target,old,decay);
    // New opaque walls must never retain old light. Quantize tiny tails to zero.
    bool wall=imageLoad(lwVoxelOccupancy,local).r>=LW_VOXEL_WALL;
    if(wall) value=vec4(0.0);
    bool pending;
    value=settleHistory(value,target,old,wall,pending);
    if(pending) atomicOr(transitioning,1u);
    if(!valid || any(notEqual(value,old))) imageStore(lwVoxelFirst,historyCell,value);
    if(max(max(target.r,max(target.g,target.b)),max(value.r,max(value.g,value.b)))>0.0) atomicOr(occupied,1u);
#ifdef LW_VOXEL_DIFFUSE_SMOOTH
    // Raw diffuse propagation remains independent. A separate world-space
    // history follows its own irradiance, including hue changes and removals.
    vec4 diffuseTarget=imageLoad(lwVoxelSecond,cell);
    vec4 diffuseOld=valid?imageLoad(lwVoxelSecond,historyCell):diffuseTarget;
    float diffuseFactor=dot(diffuseTarget.rgb,vec3(0.2126,0.7152,0.0722))>dot(diffuseOld.rgb,vec3(0.2126,0.7152,0.0722))?diffuseDecay.x:diffuseDecay.y;
    vec4 diffuseValue=mix(diffuseTarget,diffuseOld,diffuseFactor);
    if(wall) diffuseValue=vec4(0.0);
    bool diffusePending;
    diffuseValue=settleHistory(diffuseValue,diffuseTarget,diffuseOld,wall,diffusePending);
    if(diffusePending) atomicOr(transitioning,2u);
    if(!valid || any(notEqual(diffuseValue,diffuseOld))) imageStore(lwVoxelSecond,historyCell,diffuseValue);
    // Union support ensures the tile cannot be skipped while diffuse tails remain.
    if(max(max(diffuseTarget.r,max(diffuseTarget.g,diffuseTarget.b)),max(diffuseValue.r,max(diffuseValue.g,diffuseValue.b)))>0.0) atomicOr(occupied,2u);
#endif
    barrier();
    // The original dirty seed slab is no longer needed by propagation.
    if(gl_LocalInvocationIndex==0u) {
        imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(occupied));
        imageStore(lwVoxelFirst,tileMeta,vec4(float(occupied),float(transitioning),0.0,0.0));
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
