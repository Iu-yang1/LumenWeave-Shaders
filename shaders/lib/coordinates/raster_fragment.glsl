#include "/lib/coordinates/raster_viewport.glsl"
void lwRasterDiscardOutside(){
#ifdef LW_GEOMETRY_TAAU
    if(any(greaterThanEqual(gl_FragCoord.xy,vec2(lwRasterExtent(lwViewportStorage(1)))))) discard;
#endif
}
