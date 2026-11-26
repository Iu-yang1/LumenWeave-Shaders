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
// Two disjoint parity banks; no workgroup may read a bank being written.
ivec3 historyTileMeta(ivec3 tile,int parity){
    int side=LW_GRID_SIZE/4;
    int index=tile.x+side*(tile.y+side*tile.z);
    return ivec3(index%LW_GRID_SIZE,(index/LW_GRID_SIZE)%LW_GRID_SIZE,2*LW_GRID_SIZE+2*parity+index/(LW_GRID_SIZE*LW_GRID_SIZE));
}
vec2 priorTileState(ivec3 tile,int parity){return imageLoad(lwVoxelFirst,historyTileMeta(tile,parity)).rg;}
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
    if(gl_LocalInvocationIndex==0u){
        previous=imageLoad(lwVoxelMeta,ivec2(0));
        origin=voxelCacheOrigin();
        occupied=0u;
        transitioning=0u;
        ivec3 tile=ivec3(gl_WorkGroupID);
        int parity=frameCounter&1;
        tileMeta=historyTileMeta(tile,parity);
        ivec3 movement=cameraPositionInt-previous.xyz;
        bool fresh=previous.w==frameCounter-1;
        ivec3 lo=tile*4+movement,hi=lo+ivec3(3);
        skipTile=false;
        previousSupport=0u;
        uint mask=imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r;
        // Entering cells or dirty targets must be processed. A retained
        // tile may overlap 1..8 old tiles when the camera crosses a block.
        if(fresh && (mask&3u)==0u && withinVoxelGrid(lo) && withinVoxelGrid(hi)){
            ivec3 first=lo/4,last=hi/4;
            vec2 prior=priorTileState(first,1-parity);
            if(all(equal(first,last))){
                // Exact tile mapping: reuse settled support even when lit.
                previousSupport=uint(prior.r);
                skipTile=prior.g==0.0;
            }else if(prior.r==0.0 && prior.g==0.0){
                // Misaligned tiles can only reuse proven empty history.
                // Do not spread conservative lit flags on repeated movement.
                skipTile=true;
                for(int z=first.z;z<=last.z && skipTile;++z)
                    for(int y=first.y;y<=last.y && skipTile;++y)
                        for(int x=first.x;x<=last.x && skipTile;++x){
                            ivec3 p=ivec3(x,y,z);
                            if(all(equal(p,first))) continue;
                            vec2 state=priorTileState(p,1-parity);
                            skipTile=state.r==0.0 && state.g==0.0;
                        }
            }
        }
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
            imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(previousSupport));
            imageStore(lwVoxelFirst,tileMeta,vec4(float(previousSupport),0.0,0.0,0.0));
        }
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
    if(hasHistorySupport(target) || hasHistorySupport(value)) atomicOr(occupied,1u);
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
    if(hasHistorySupport(diffuseTarget) || hasHistorySupport(diffuseValue)) atomicOr(occupied,2u);
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
