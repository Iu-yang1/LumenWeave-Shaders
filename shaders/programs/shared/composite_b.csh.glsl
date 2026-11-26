#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_grid.glsl"
layout(local_size_x=8,local_size_y=8) in;
#if defined(LW_SCENE_TAAU) && SCENE_TAAU_SCALE == 50
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.125,0.125);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.1675,0.1675);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.1875,0.1875);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.2125,0.2125);
#else
const vec2 workGroupsRender=vec2(0.25,0.25);
#endif
#elif defined(LW_SCENE_TAAU) && SCENE_TAAU_SCALE == 67
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.1675,0.1675);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.22445,0.22445);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.25125,0.25125);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.28475,0.28475);
#else
const vec2 workGroupsRender=vec2(0.335,0.335);
#endif
#elif defined(LW_SCENE_TAAU) && SCENE_TAAU_SCALE == 75
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.1875,0.1875);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.25125,0.25125);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.28125,0.28125);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.31875,0.31875);
#else
const vec2 workGroupsRender=vec2(0.375,0.375);
#endif
#elif defined(LW_SCENE_TAAU) && SCENE_TAAU_SCALE == 85
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.2125,0.2125);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.28475,0.28475);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.31875,0.31875);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.36125,0.36125);
#else
const vec2 workGroupsRender=vec2(0.425,0.425);
#endif
#else
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.25,0.25);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.335,0.335);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.375,0.375);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.425,0.425);
#else
const vec2 workGroupsRender=vec2(0.5,0.5);
#endif
#endif
#ifdef LW_SCENE_TAAU
#include "/lib/temporal/scene_grid.glsl"
#endif
#ifdef LW_CELESTIAL_VOLUME_SPATIAL
#include "/lib/lighting/overworld.glsl"
#include "/lib/atmosphere/volume_depth.glsl"
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif
#include "/lib/atmosphere/volume.glsl"
#include "/lib/atmosphere/volume_spatial.glsl"
#ifdef LW_VOLUME_TEMPORAL_ACTIVE
#include "/lib/atmosphere/volume_temporal.glsl"
#endif
layout(rgba16f) writeonly uniform image2D colorimg9;
#ifdef LW_AO_SPATIAL
layout(rg16f) writeonly uniform image2D colorimg3;
#endif
void main() {
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    ivec2 size=lwRasterExtent(imageSize(colorimg9));
#ifdef LW_SCENE_TAAU
    size=lwSceneRenderSize(size);
#endif
    if(any(greaterThanEqual(p,size))) return;
    vec4 result=vec4(0.0,0.0,0.0,1.0);
    float distanceToSurface=0.0;
    bool volumeVisible=isEyeInWater==0 && hasSkylight;
    vec3 direction=vec3(0,1,0);
    if(volumeVisible) volumeRay((vec2(p)+0.5)/vec2(size),direction,distanceToSurface);
#ifdef LW_VOLUME_TEMPORAL_ACTIVE
    result=temporalCelestialVolume(p,size,direction,distanceToSurface,volumeVisible);
#else
    if(volumeVisible) result=celestialVolumeTransfer(direction,distanceToSurface);
#endif
    imageStore(colorimg9,p,result);
#ifdef LW_AO_SPATIAL
    // GTAO is consumed by deferred1 before this pass, so reuse its RG16F
    // attachment for donor ray distances. Both targets have the same size.
    imageStore(colorimg3,p,vec4(distanceToSurface,0.0,0.0,0.0));
#endif
}
#else
void main(){}
#endif
