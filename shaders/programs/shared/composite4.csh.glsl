#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups = ivec3(1, 1, 1);
#ifdef LW_EXPOSURE_METER
#include "/lib/color/scene.glsl"
layout(rg32f) uniform image2D lwExposureState;
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_METER_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_METER_SOURCE colortex0
#endif
uniform float frameTime;
void main(){
    float sum=0.0,weight=0.0;
    for(int y=0;y<7;++y) for(int x=0;x<7;++x) {
        vec2 uv=(vec2(x,y)+0.5)/7.0;
        float w=1.0-0.65*length(uv-0.5);
        float l=clamp(luminance(textureLod(LW_METER_SOURCE,uv,0.0).rgb),0.012,4.0);
        sum+=log2(l)*w;weight+=w;
    }
    // Keep night intentionally dark and daylight natural, not middle gray.
    float target=clamp(log2(0.18)-sum/weight,-0.75,1.0)*EXPOSURE_ADAPTATION;
    float old=imageLoad(lwExposureState,ivec2(0)).r;
    float halfLife=target<old ? 0.42 : 1.25;
    float next=mix(target,old,exp2(-clamp(frameTime,0.0,0.25)/halfLife));
    imageStore(lwExposureState,ivec2(0),vec4(next,target,0,0));
}
#else
void main(){}
#endif
