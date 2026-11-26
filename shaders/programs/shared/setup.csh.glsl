#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const ivec3 workGroups = ivec3(16, 4, 1);
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
#include "/lib/atmosphere/physical_common.glsl"
#if ATMO_PREBAKED != 1
layout(rgba16f) writeonly uniform image2D lwAtmoTransImage;
#endif
#ifdef LW_ATMO_CACHE_ACTIVE
layout(rgba32f) writeonly uniform image2D lwAtmoState;
#endif
void main(){
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    #ifdef LW_ATMO_CACHE_ACTIVE
    if(all(equal(p,ivec2(0)))) imageStore(lwAtmoState,ivec2(0),vec4(0.0));
    #endif
    #if ATMO_PREBAKED != 1
    vec2 uv=vec2(p)/vec2(127,31);
    float r=atmoAltitudeRadius(uv.y);
    float mu=mix(atmoHorizon(r),1.0,uv.x*uv.x);
    imageStore(lwAtmoTransImage,p,vec4(atmoTransmittance(r,min(mu+1e-6,1.0)),1.0));
    #endif
}
#else
void main(){}
#endif
