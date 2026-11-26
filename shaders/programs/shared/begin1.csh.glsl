#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const ivec3 workGroups=ivec3(16,8,1);
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
#include "/lib/atmosphere/physical_integrate.glsl"
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
layout(rgba16f) writeonly uniform image2D lwAtmoSkyImage;
void main(){
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    vec2 uv=vec2(p)/vec2(127,63);
    float mu=normalize(mat3(gbufferModelViewInverse)*sunPosition).y;
    vec3 l,t,f;
    atmoIntegrate(atmoRadius(cameraPosition.y),atmoDirection(uv.y*2.0-1.0,uv.x*ATMO_PI),
        atmoDirection(mu,0.0),1e6,true,32,l,t,f);
    imageStore(lwAtmoSkyImage,p,vec4(l,1.0));
}
#else
void main(){}
#endif
