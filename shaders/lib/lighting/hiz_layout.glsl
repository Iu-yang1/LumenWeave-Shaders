#ifndef LW_HIZ_LAYOUT
#define LW_HIZ_LAYOUT
ivec2 hizLevelSize(ivec2 resolution,int scale) {
    return (resolution+scale-1)/scale;
}
ivec2 hizAtlasOffset(ivec2 resolution,int scale) {
#if HIZ_MODE == 1
    return ivec2(0);
#else
    int y=scale==4 ? 0 : hizLevelSize(resolution,4).y;
    if(scale==64) y+=hizLevelSize(resolution,16).y;
    return ivec2(0,y);
#endif
}
bool hizAtlasFits(ivec2 resolution,ivec2 atlasSize) {
#if HIZ_MODE == 1
    return all(lessThanEqual(hizLevelSize(resolution,64),atlasSize));
#else
    return hizLevelSize(resolution,4).x<=atlasSize.x &&
        hizLevelSize(resolution,4).y+hizLevelSize(resolution,16).y+
        hizLevelSize(resolution,64).y<=atlasSize.y;
#endif
}
#endif
