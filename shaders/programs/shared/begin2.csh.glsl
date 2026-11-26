#include "/lib/quality.glsl"
layout(local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(4, 4, 1);
#if defined(LW_ATMOSPHERE_LUT_ACTIVE) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
#include "/lib/atmosphere/physical_integrate.glsl"
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
#include "/lib/atmosphere/update_cache.glsl"
layout(rgba16f) writeonly uniform image3D lwAtmoScatterImage;
layout(rgba16f) writeonly uniform image3D lwAtmoThroughImage;
void main(){
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
    vec2 uv=vec2(pixel)/vec2(31,31);
    float mu=normalize(mat3(gbufferModelViewInverse)*sunPosition).y;
#ifdef LW_ATMO_CACHE_ACTIVE
    if(!atmoUpdateNeeded(float(cameraPositionInt.y)+cameraPositionFract.y,mu)) return;
#endif
    vec3 sun=atmoDirection(mu,0.0);
    vec3 direction=atmoViewDirection(atmoElevationMu(uv.y),uv.x);
    float radius=atmoRadius(float(cameraPositionInt.y)+cameraPositionFract.y);
    float boundary=atmoBoundary(radius,direction.y).x;
    vec3 l=vec3(0.0),t=vec3(1.0),f=vec3(0.0);
    float previous=0.0;
    // Prefix integral: each direction is integrated once, not from the
    // camera separately for every slice. 15 intervals * 4 substeps.
    for(int z=0;z<16;++z) {
        float distanceKm=min(boundary,exp(log(1.0+ATMO_MAX_DISTANCE)*float(z)/15.0)-1.0);
        atmoIntegrateSegment(radius,direction,sun,previous,distanceKm,4,l,t,f);
        imageStore(lwAtmoScatterImage,ivec3(pixel,z),vec4(l,1.0));
        imageStore(lwAtmoThroughImage,ivec3(pixel,z),vec4(t,1.0));
        previous=distanceKm;
    }
}
#else
void main(){}
#endif
