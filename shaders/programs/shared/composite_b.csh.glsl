#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const vec2 workGroupsRender=vec2(0.5,0.5);
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
    ivec2 size=imageSize(colorimg9);
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
