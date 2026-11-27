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
#include "/lib/voxel/seed_source.glsl"
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
layout(r8ui) uniform uimage3D lwVoxelDirtyTiles;
uniform int frameCounter;
uniform float frameTime;
shared ivec4 previous;
shared ivec3 origin;
shared uint historyFlags[64];
shared uint previousSupport;
shared bool skipTile;
shared ivec3 tileMeta;
// Two disjoint parity banks; no workgroup may read a bank being written.
#include "/lib/voxel/history_tiles.glsl"
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
#endif
bool hasHistorySupport(vec4 v){return any(greaterThan(v,vec4(0.0)));}
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
#ifdef LW_GPU_COMPACTION
    ivec3 tile=activeTile(3);
#else
    ivec3 tile=ivec3(gl_WorkGroupID);
#endif
    if(gl_LocalInvocationIndex==0u){
        previous=imageLoad(lwVoxelMeta,ivec2(0));
        origin=voxelCacheOrigin();
        tileMeta=historyTileMeta(tile,frameCounter&1);
#ifdef LW_GPU_COMPACTION
        skipTile=false;
#else
        uint mask=imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r;
        skipTile=historyTileReusable(tile,previous,mask,previousSupport);
#endif
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
        if(gl_LocalInvocationIndex==0u){
            retainHistoryTile(tile,previousSupport);
        }
        return;
    }
    initializeVoxelSeedSource();
    ivec3 local=tile*4+ivec3(gl_LocalInvocationID);
    ivec3 cell=voxelWrapNear(local+origin);
    ivec3 historyCell=cell+ivec3(0,0,LW_GRID_SIZE);
    ivec3 previousLocal=local+cameraPositionInt-previous.xyz;
    bool valid=previous.w==frameCounter-1 && withinVoxelGrid(previousLocal);
    vec4 target=imageLoad(lwVoxelFirst,cell);
    vec4 old=valid?imageLoad(lwVoxelFirst,historyCell):target;
    float decay=dot(target.rgb,vec3(0.2126,0.7152,0.0722))>dot(old.rgb,vec3(0.2126,0.7152,0.0722))?directDecay.x:directDecay.y;
    vec4 value=mix(target,old,decay);
    // New opaque walls must never retain old light. Quantize tiny tails to zero.
    bool wall=voxelSeedAt(local)>=LW_VOXEL_WALL;
    if(wall) value=vec4(0.0);
    bool pending;
    value=settleHistory(value,target,old,wall,pending);
    uint flags=pending?4u:0u;
    if(!valid || any(notEqual(value,old))) imageStore(lwVoxelFirst,historyCell,value);
    if(hasHistorySupport(target) || hasHistorySupport(value)) flags|=1u;
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
    if(diffusePending) flags|=8u;
    if(!valid || any(notEqual(diffuseValue,diffuseOld))) imageStore(lwVoxelSecond,historyCell,diffuseValue);
    // Union support ensures the tile cannot be skipped while diffuse tails remain.
    if(hasHistorySupport(diffuseTarget) || hasHistorySupport(diffuseValue)) flags|=2u;
#endif
    // Four state bits per lane. Reduce in two stages instead of up to
    // four contended atomics per voxel on densely lit, changing tiles.
    uint lane=gl_LocalInvocationIndex;
    historyFlags[lane]=flags;
    barrier();
    if(lane<8u){
        uint mask=0u;
        for(uint i=0u;i<8u;++i) mask|=historyFlags[lane*8u+i];
        historyFlags[lane*8u]=mask;
    }
    barrier();
    if(lane==0u){
        uint combined=0u;
        for(int i=0;i<8;++i) combined|=historyFlags[i*8];
        uint occupied=combined&3u,transitioning=(combined>>2u)&3u;
        imageStore(lwVoxelDirtyTiles,tile,uvec4(occupied));
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
