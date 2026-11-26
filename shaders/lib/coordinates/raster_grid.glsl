#ifndef LW_RASTER_GRID
#define LW_RASTER_GRID
// All pre-resolve screen buffers occupy the lower-left integer active grid.
// Logical UV is always [0,1]; only normalized texture fetches map to storage.
ivec2 lwRasterExtent(ivec2 storageSize){
#ifdef LW_GEOMETRY_TAAU
    return max(storageSize*GEOMETRY_TAAU_SCALE/100,ivec2(1));
#else
    return storageSize;
#endif
}
ivec2 lwRasterSize(sampler2D source){return lwRasterExtent(textureSize(source,0));}
vec2 lwRasterStorageUv(sampler2D source,vec2 uv){
#ifdef LW_GEOMETRY_TAAU
    vec2 active=vec2(lwRasterSize(source));
    return clamp(uv*active,vec2(0.5),active-0.5)/vec2(textureSize(source,0));
#else
    return uv;
#endif
}
vec4 lwRasterTexture(sampler2D source,vec2 uv){return texture(source,lwRasterStorageUv(source,uv));}
vec4 lwRasterTextureLod(sampler2D source,vec2 uv,float lod){return textureLod(source,lwRasterStorageUv(source,uv),lod);}
#endif
