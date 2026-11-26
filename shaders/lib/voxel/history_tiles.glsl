#ifndef LW_HISTORY_TILES
#define LW_HISTORY_TILES
ivec3 historyTileMeta(ivec3 tile,int parity){
    int side=LW_GRID_SIZE/4;
    int index=tile.x+side*(tile.y+side*tile.z);
    return ivec3(index%LW_GRID_SIZE,(index/LW_GRID_SIZE)%LW_GRID_SIZE,2*LW_GRID_SIZE+2*parity+index/(LW_GRID_SIZE*LW_GRID_SIZE));
}
vec2 priorTileState(ivec3 tile,int parity){return imageLoad(lwVoxelFirst,historyTileMeta(tile,parity)).rg;}

bool historyTileReusable(ivec3 tile,ivec4 previous,uint mask,out uint previousSupport){
    int parity=frameCounter&1;
    ivec3 movement=cameraPositionInt-previous.xyz;
    bool fresh=previous.w==frameCounter-1;
    ivec3 lo=tile*4+movement,hi=lo+ivec3(3);
    previousSupport=0u;
    if(!fresh || (mask&3u)!=0u || !withinVoxelGrid(lo) || !withinVoxelGrid(hi)) return false;
    ivec3 first=lo/4,last=hi/4;
    vec2 prior=priorTileState(first,1-parity);
    if(all(equal(first,last))){
        previousSupport=uint(prior.r);
        return prior.g==0.0;
    }
    if(prior.r!=0.0 || prior.g!=0.0) return false;
    for(int z=first.z;z<=last.z;++z)
        for(int y=first.y;y<=last.y;++y)
            for(int x=first.x;x<=last.x;++x){
                ivec3 p=ivec3(x,y,z);
                if(all(equal(p,first))) continue;
                vec2 state=priorTileState(p,1-parity);
                if(state.r!=0.0 || state.g!=0.0) return false;
            }
    return true;
}
void retainHistoryTile(ivec3 tile,uint support){
    imageStore(lwVoxelDirtyTiles,tile,uvec4(support));
    imageStore(lwVoxelFirst,historyTileMeta(tile,frameCounter&1),vec4(float(support),0.0,0.0,0.0));
}
#endif
