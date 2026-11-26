#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups=ivec3(8,8,4);
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
#include "/lib/atmosphere/physical_integrate.glsl"
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
layout(rgba16f) writeonly uniform image3D lwAtmoScatterImage;
layout(rgba16f) writeonly uniform image3D lwAtmoThroughImage;
void main(){
    ivec3 p=ivec3(gl_GlobalInvocationID);
    vec3 uv=vec3(p)/vec3(31,31,15);
    float mu=normalize(mat3(gbufferModelViewInverse)*sunPosition).y;
    float distanceKm=exp(log(1.0+ATMO_MAX_DISTANCE)*uv.z)-1.0;
    vec3 l,t,f;
    atmoIntegrate(atmoRadius(cameraPosition.y),atmoDirection(uv.y*2.0-1.0,uv.x*ATMO_PI),
        atmoDirection(mu,0.0),distanceKm,false,24,l,t,f);
    imageStore(lwAtmoScatterImage,p,vec4(l,1.0));
    imageStore(lwAtmoThroughImage,p,vec4(t,1.0));
}
#else
void main(){}
#endif
