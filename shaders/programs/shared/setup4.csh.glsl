#include "/lib/quality.glsl"
layout(local_size_x=1) in;
// Iris parses the constructor text, not GLSL scalar splatting.
const ivec3 workGroups = ivec3(1, 1, 1);
#ifdef LW_CLOUD_CACHE_ACTIVE
layout(rg16f) writeonly uniform image2D lwCloudShapeImage;
void main(){ imageStore(lwCloudShapeImage,ivec2(512,2),vec4(0)); }
#else
void main(){}
#endif
