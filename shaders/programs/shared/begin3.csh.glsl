#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups=ivec3(1,1,1);
#ifdef LW_ATMO_CACHE_ACTIVE
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
#include "/lib/atmosphere/update_cache.glsl"
void main() {
    float h=float(cameraPositionInt.y)+cameraPositionFract.y;
    float mu=normalize(mat3(gbufferModelViewInverse)*sunPosition).y;
    if(mu<=-0.15) {
        imageStore(lwAtmoState,ivec2(0),vec4(0.0));
    } else if(atmoUpdateNeeded(h,mu)) {
        imageStore(lwAtmoState,ivec2(0),vec4(h,mu,frameTimeCounter,1.0));
    }
}
#else
void main(){}
#endif
