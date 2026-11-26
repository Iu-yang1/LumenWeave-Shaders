#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"
layout(local_size_x=8,local_size_y=8) in;
const vec2 workGroupsRender = vec2(0.25,0.25);
#ifdef LW_SCATTER_UPSAMPLE_ACTIVE
#include "/lib/lighting/overworld.glsl"
#include "/lib/atmosphere/volume_depth.glsl"
#include "/lib/atmosphere/local_scatter.glsl"
layout(rgba16f) writeonly uniform image2D colorimg11;
void main() {
    ivec2 size=imageSize(colorimg11);
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(p,size))) return;
    vec4 result=vec4(0.0);
    if(isEyeInWater==0) {
        vec2 uv=(vec2(p)+0.5)/vec2(size);
        vec3 direction;
        float distanceToSurface;
        volumeRay(uv,direction,distanceToSurface);
        result=vec4(integrateLocalScatter(direction,distanceToSurface),
                    min(distanceToSurface,float(LW_GRID_SIZE)*0.5-1.0));
    }
    imageStore(colorimg11,p,result);
}
#else
void main(){}
#endif
