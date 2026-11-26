#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const ivec3 workGroups = ivec3(4, 2, 1);
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
#define LW_ATMO_SINGLE_ONLY
#include "/lib/atmosphere/physical_integrate.glsl"
layout(rgba16f) writeonly uniform image2D lwAtmoMultiImage;
void main(){
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    vec2 uv=vec2(p)/vec2(31,15);
    float radius=atmoAltitudeRadius(uv.y);
    vec3 sun=atmoDirection(atmoElevationMu(uv.x),0.0);
    vec3 source=vec3(0.0), feedback=vec3(0.0);
    for(int i=0;i<24;++i){
        vec3 direction=atmoDirection(1.0-2.0*(float(i)+0.5)/24.0,float(i)*2.39996323);
        vec3 l,t,f;
        atmoIntegrate(radius,direction,sun,1e6,true,24,l,t,f);
        source+=l/24.0;feedback+=f/24.0;
    }
    imageStore(lwAtmoMultiImage,p,vec4(source/max(1.0-feedback,vec3(0.02)),1.0));
}
#else
void main(){}
#endif
