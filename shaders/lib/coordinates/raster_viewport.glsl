#ifndef LW_RASTER_VIEWPORT
#define LW_RASTER_VIEWPORT
#include "/lib/coordinates/raster_grid.glsl"
#ifndef LW_VIEW_SIZE_UNIFORMS
#define LW_VIEW_SIZE_UNIFORMS
uniform float viewWidth;
uniform float viewHeight;
#endif
ivec2 lwViewportStorage(int divisor){return max(ivec2(viewWidth,viewHeight)/divisor,ivec2(1));}
vec4 lwRasterClip(vec4 clip,int divisor){
#ifdef LW_GEOMETRY_TAAU
    ivec2 storage=lwViewportStorage(divisor);
    vec2 s=vec2(lwRasterExtent(storage))/vec2(storage);
    clip.xy=clip.xy*s+(s-1.0)*clip.w;
#endif
    return clip;
}
#endif
