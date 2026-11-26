#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups = ivec3(1, 1, 1);
#ifdef LW_EXPOSURE_METER
layout(rg32f) writeonly uniform image2D lwExposureState;
void main(){imageStore(lwExposureState,ivec2(0),vec4(0.0));}
#else
void main(){}
#endif
