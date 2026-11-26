#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups=ivec3(1,1,1);
#if defined(LW_MOTION_DOF_FUSED) && defined(LW_AUTO_FOCUS)
#include "/lib/post/autofocus.glsl"
layout(rgba32f) uniform image2D lwExposureState;
uniform float frameTime;
void main(){imageStore(lwExposureState,ivec2(1,0),lwAdvanceFocus(imageLoad(lwExposureState,ivec2(1,0)),frameTime));}
#else
void main(){}
#endif
