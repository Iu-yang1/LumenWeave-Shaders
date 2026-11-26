#ifndef LW_RASTER_GRID
#define LW_RASTER_GRID
// All pre-resolve screen buffers occupy the lower-left integer activeSize grid.
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
    vec2 activeSize=vec2(lwRasterSize(source));
    return clamp(uv*activeSize,vec2(0.5),activeSize-0.5)/vec2(textureSize(source,0));
#else
    return uv;
#endif
}
#ifdef LW_GEOMETRY_TAAU
uniform int lwRasterFrame;
#ifndef LW_VIEW_SIZE_UNIFORMS
#define LW_VIEW_SIZE_UNIFORMS
uniform float viewWidth;
uniform float viewHeight;
#endif
vec2 lwGeometryJitter(int frame,ivec2 activeSize){
// Fixed is a real zero-jitter geometry mode, not just a native-grid flag.
// Auto chooses stable geometry for the advanced lighting paths.
#if PROJECTION_JITTER == 1 || (PROJECTION_JITTER == 0 && (defined(VOLUME_EFFECTS) || defined(SCREEN_GI) || defined(VOXEL_LIGHTING) || defined(MATERIAL_SSR)))
    return vec2(0.0);
#else
    const vec2 sequence[8] = vec2[8](
        vec2(0.0, -0.16667), vec2(-0.25, 0.16667),
        vec2(0.25, -0.38889), vec2(-0.375, -0.05556),
        vec2(0.125, 0.27778), vec2(-0.125, -0.27778),
        vec2(0.375, 0.05556), vec2(-0.4375, 0.38889)
    );
    // Center the finite sequence, not only its theoretical Halton distribution.
    const vec2 mean = vec2(-0.0546875, 0.0);
    return (sequence[frame&7]-mean)/vec2(max(activeSize,ivec2(1)));
#endif
}
#endif
vec2 lwPostDepthUv(sampler2D source,vec2 uv){
#ifdef LW_GEOMETRY_TAAU
    uv+=lwGeometryJitter(lwRasterFrame,lwRasterExtent(max(ivec2(viewWidth,viewHeight),ivec2(1))));
#endif
    return lwRasterStorageUv(source,uv);
}
float lwPostDepth(sampler2D source,vec2 uv){
#ifdef LW_GEOMETRY_TAAU
    ivec2 size=textureSize(source,0);
    ivec2 pixel=clamp(ivec2(lwPostDepthUv(source,uv)*vec2(size)),ivec2(0),lwRasterSize(source)-1);
    return texelFetch(source,pixel,0).r;
#else
    return textureLod(source,uv,0.0).r;
#endif
}
vec4 lwRasterTexture(sampler2D source,vec2 uv){return texture(source,lwRasterStorageUv(source,uv));}
vec4 lwRasterTextureLod(sampler2D source,vec2 uv,float lod){return textureLod(source,lwRasterStorageUv(source,uv),lod);}
#endif
