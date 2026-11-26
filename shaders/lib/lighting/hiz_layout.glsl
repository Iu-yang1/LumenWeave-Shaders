#ifndef LW_HIZ_LAYOUT
#define LW_HIZ_LAYOUT
ivec2 hizLevelSize(ivec2 resolution,int scale) {
    return (resolution+scale-1)/scale;
}
ivec2 hizAtlasOffset(ivec2 resolution,int scale,bool solid) {
    int y=scale==4 ? 0 : hizLevelSize(resolution,4).y;
    if(scale==64) y+=hizLevelSize(resolution,16).y;
    return ivec2(solid ? hizLevelSize(resolution,4).x : 0,y);
}
bool hizAtlasFits(ivec2 resolution,ivec2 atlasSize) {
    return 2*hizLevelSize(resolution,4).x<=atlasSize.x &&
        hizLevelSize(resolution,4).y+hizLevelSize(resolution,16).y+
        hizLevelSize(resolution,64).y<=atlasSize.y;
}
#endif
