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
layout(rgba16f) writeonly uniform image2D colorimg9;
void main() {
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    ivec2 size=imageSize(colorimg9);
    if(any(greaterThanEqual(p,size))) return;
    vec4 result=vec4(0.0,0.0,0.0,1.0);
    if(isEyeInWater==0 && hasSkylight) {
        vec3 direction;float distanceToSurface;
        volumeRay((vec2(p)+0.5)/vec2(size),direction,distanceToSurface);
        result=celestialVolumeTransfer(direction,distanceToSurface);
    }
    imageStore(colorimg9,p,result);
}
#else
void main(){}
#endif
