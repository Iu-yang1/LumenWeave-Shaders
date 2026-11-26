#ifndef LW_CLOUD_CACHE_COORDS
#define LW_CLOUD_CACHE_COORDS
// 512 cells spaced three blocks apart, snapped in 32-cell increments.
// Wind is part of the world coordinate, not a reason to rebuild the map.
ivec2 cloudCacheOrigin() {
    vec2 center=vec2(cameraPositionInt.xz)+cameraPositionFract.xz
        +frameTimeCounter*vec2(1.1,0.40);
    return ivec2(floor(center/96.0))*32-ivec2(256);
}
ivec2 cloudWrap(ivec2 p) { return p & ivec2(511); }
ivec2 cloudCellForPixel(ivec2 p,ivec2 origin) {
    return origin+cloudWrap(p-origin);
}
// Origin is stored as signed high/unsigned low base-1024 digits, exactly
// representable in binary16 over Minecraft's supported world border.
vec2 cloudEncode(int value) {
    int hi=int(floor(float(value)/1024.0));
    return vec2(float(hi),float(value-hi*1024));
}
int cloudDecode(vec2 value) { return int(value.x)*1024+int(value.y); }
#endif
