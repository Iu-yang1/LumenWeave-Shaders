#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups=ivec3(1);
#ifdef LW_CLOUD_CACHE_ACTIVE
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;
#include "/lib/atmosphere/cloud_cache.glsl"
layout(rg16f) uniform image2D lwCloudShapeImage;
void main(){
    ivec2 origin=cloudCacheOrigin();
    imageStore(lwCloudShapeImage,ivec2(512,0),vec4(cloudEncode(origin.x),0,0));
    imageStore(lwCloudShapeImage,ivec2(512,1),vec4(cloudEncode(origin.y),0,0));
    imageStore(lwCloudShapeImage,ivec2(512,2),vec4(1,0,0,0));
}
#else
void main(){}
#endif
