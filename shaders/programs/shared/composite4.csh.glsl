#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups = ivec3(1, 1, 1);
#ifdef LW_EXPOSURE_METER
#include "/lib/color/scene.glsl"
layout(rgba32f) uniform image2D lwExposureState;
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_METER_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_METER_SOURCE colortex0
#endif
uniform float frameTime;
uniform int frameCounter;
#ifdef SOLAR_GLARE
#include "/lib/post/solar_visibility.glsl"
#else
uniform sampler2D depthtex0;
#endif
void main(){
    float sum=0.0,weight=0.0,terrainSum=0.0,terrainWeight=0.0;
    // Rotate four subcell phases. Sky contributes, but does not drown the terrain meter.
    vec2 phase=vec2(float(frameCounter&1),float((frameCounter>>1)&1))*0.5+0.25;
    for(int y=0;y<9;++y) for(int x=0;x<9;++x) {
        vec2 uv=(vec2(x,y)+phase)/9.0;
        float w=1.0-0.65*length(uv-0.5);
        float l=clamp(luminance(textureLod(LW_METER_SOURCE,uv,0.0).rgb),0.012,4.0);
        float logL=log2(l);
        sum+=logL*w;weight+=w;
        float ground=1.0-step(0.999999,textureLod(depthtex0,uv,0.0).r);
        terrainSum+=logL*w*ground;terrainWeight+=w*ground;
    }
    float average=sum/weight;
    if(terrainWeight>0.0) average=mix(average,terrainSum/terrainWeight,0.65*smoothstep(0.08,0.45,terrainWeight/weight));
    // Keep night intentionally dark and daylight natural, not middle gray.
    float target=clamp(log2(0.18)-average,-0.75,1.0)*EXPOSURE_ADAPTATION;
    vec4 previous=imageLoad(lwExposureState,ivec2(0));
    float old=previous.r;
    float halfLife=target<old ? 0.42 : 1.25;
    float next=mix(target,old,exp2(-clamp(frameTime,0.0,0.25)/halfLife));
    float glare=0.0;
#ifdef SOLAR_GLARE
    float current=solarVisibility(LW_METER_SOURCE).z;
    glare=min(current,mix(current,previous.b,exp2(-clamp(frameTime,0.0,0.25)/0.10)));
#endif
    imageStore(lwExposureState,ivec2(0),vec4(next,old,glare,target));
}
#else
void main(){}
#endif
