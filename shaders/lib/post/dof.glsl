#include "/lib/post/camera_depth.glsl"
uniform float centerDepthSmooth;
#ifndef LW_VIEW_SIZE_UNIFORMS
#define LW_VIEW_SIZE_UNIFORMS
uniform float viewWidth;
uniform float viewHeight;
#endif
// Iris uses ticks, not seconds. Legacy native-depth fallback only.
const float centerDepthHalflife = 4.4;
#ifdef LW_AUTO_FOCUS
#ifndef LW_CAMERA_STATE_SAMPLER
#define LW_CAMERA_STATE_SAMPLER
uniform sampler2D lwExposureSampler;
#endif
#endif
float lwFocusDepth(){
#if DOF_MODE == 2
    return DOF_FOCUS;
#elif defined(LW_AUTO_FOCUS)
    vec4 state=texelFetch(lwExposureSampler,ivec2(1,0),0);
    return state.a>0.5?1.0/max(state.r,1.0/512.0):DOF_FOCUS;
#elif defined(LW_GEOMETRY_TAAU)
    // Loader center is outside the logical reticle at reduced scale.
    // Without persistent camera state, keep the user-set focus stable.
    return DOF_FOCUS;
#else
    return clamp(lwLinearDepth(gbufferProjectionInverse,clamp(centerDepthSmooth,0.56,1.0)),0.65,512.0);
#endif
}
float lwCoC(float depth,float focus) {
    if(depth<=0.0) return 0.0;
    float strength=DOF_STRENGTH;
#if DOF_MODE == 3
    strength*=1.8;
#endif
    // Scale optical blur with output height; continuous focus dead band.
    float power=1.0/focus-1.0/depth;
    float magnitude=max(abs(power)-0.003,0.0);
    float pixelScale=max(viewHeight,1.0)/1080.0;
    float radius=magnitude*48.0*strength*pixelScale;
    return sign(power)*min(radius,14.0*pixelScale);
}
vec3 lwDofGather(sampler2D source,vec2 uv,vec3 center,float depth,float coc,float focus) {
    if(depth<=0.0) return center;
    vec2 texel=1.0/vec2(textureSize(source,0));
    const vec2 taps[8]=vec2[8](vec2(1,0),vec2(0,1),vec2(-1,0),vec2(0,-1),vec2(0.707,0.707),vec2(-0.707,0.707),vec2(-0.707,-0.707),vec2(0.707,-0.707));
#if DOF_QUALITY == 0
    const int count=4;
#else
    const int count=8;
#endif
#ifdef LW_DOF_MIP_ASSIST
    // Four cardinal depth probes reject common silhouettes before sampling
    // a coarse HDR mip. Thin geometry may still alias: opt-in experiment.
    if(abs(coc)>3.0){
        bool compatible=true;
        for(int i=0;i<4;++i){
            vec2 probe=clamp(uv+taps[i]*texel*abs(coc),texel*0.5,1.0-texel*0.5);
            float z=lwDofDepth(probe);
            compatible=compatible && z>0.0 && abs(z-depth)<max(0.06,depth*0.035);
        }
        if(compatible){
            float lod=clamp(log2(abs(coc))-1.4,0.0,3.5);
            vec2 offset=vec2(0.36,0.27)*texel*abs(coc);
            vec3 mipColor=0.5*(textureLod(source,clamp(uv-offset,texel*0.5,1.0-texel*0.5),lod).rgb+
                textureLod(source,clamp(uv+offset,texel*0.5,1.0-texel*0.5),lod).rgb);
            return mix(center,mipColor,smoothstep(3.0,5.0,abs(coc)));
        }
    }
#endif
    vec3 farSum=center,nearSum=vec3(0.0);
    float farTotal=1.0,nearTotal=0.0;
    // A smooth radius and weight avoid the old hard 0.65-pixel switch.
    float radius=abs(coc), blur=smoothstep(0.15,1.5,radius);
    float pixelScale=max(viewHeight,1.0)/1080.0;
    float nearRadius=max(radius,5.0*pixelScale);
    for(int i=0;i<count;++i){
        // One depth/color pair per direction, plus optional close foreground dilation.
        vec2 p=clamp(uv+taps[i]*texel*max(radius,1.0),texel*0.5,1.0-texel*0.5);
        float d=lwDofDepth(p);
        if(d>0.0){
            float w=blur*(1.0-smoothstep(0.04,0.23,abs(d-depth)/max(depth,0.5)));
            float cover=smoothstep(radius-1.0,radius+1.0,-lwCoC(d,focus))*float(d<depth*0.97);
            if(w+cover>0.001){
                vec3 sampleColor=texture(source,p).rgb;
                farSum+=sampleColor*w;farTotal+=w;
                nearSum+=sampleColor*cover;nearTotal+=cover;
            }
        }
#if DOF_QUALITY > 0
        // Four extra cardinal donors in Balanced; all eight in Cinematic.
        // Fade the extra ring as it merges into the primary sampling disk.
        float ring=DOF_QUALITY==2?max(radius,10.0*pixelScale):nearRadius;
        float ringWeight=smoothstep(0.25,1.5,(ring-radius)/pixelScale);
        if(ringWeight>0.0 && (DOF_QUALITY==2 || i<4)){
            vec2 q=clamp(uv+taps[i]*texel*ring,texel*0.5,1.0-texel*0.5);
            float nearDepth=lwDofDepth(q);
            if(nearDepth>0.0 && nearDepth<depth*0.97){
                float cover=ringWeight*smoothstep(ring-1.5*pixelScale,ring+1.5*pixelScale,-lwCoC(nearDepth,focus));
                if(cover>0.001){nearSum+=texture(source,q).rgb*cover;nearTotal+=cover;}
            }
        }
#endif
    }
    return mix(farSum/farTotal,nearSum/max(nearTotal,0.0001),clamp(nearTotal/float(count),0.0,1.0));
}
// Four depth-compatible half-resolution donors. Never trigger an entire
// full-resolution disk gather at a depth discontinuity.
vec3 lwDofResolve(sampler2D blurred,vec2 uv,vec3 center,float depth,float focus){
    ivec2 size=textureSize(blurred,0);
    vec2 pos=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(pos));vec2 f=fract(pos);
    vec3 sum=vec3(0.0),nearSum=vec3(0.0);
    float total=0.0,nearTotal=0.0;
    for(int y=0;y<2;++y)for(int x=0;x<2;++x){
        vec4 s=texelFetch(blurred,clamp(base+ivec2(x,y),ivec2(0),size-1),0);
        if(s.a<=0.0) continue;
        vec2 w=mix(1.0-f,f,vec2(x,y));
        float weight=w.x*w.y*(1.0-smoothstep(0.035,0.18,abs(s.a-depth)/max(depth,0.5)));
        sum+=s.rgb*weight;total+=weight;
        // Closer defocused donors may cover a sharp background at a silhouette.
        // A distant donor must never contaminate a sharp foreground.
        if(s.a<depth*0.97){
            vec2 outputSize=vec2(size)*2.0;
            float distancePixels=length((vec2(base+ivec2(x,y))+0.5-pos-0.5)*outputSize/vec2(size));
            float coverage=smoothstep(distancePixels,distancePixels+2.0,-lwCoC(s.a,focus));
            float nearWeight=w.x*w.y*coverage;
            nearSum+=s.rgb*nearWeight;nearTotal+=nearWeight;
        }
    }
    float blur=smoothstep(0.15,1.5,abs(lwCoC(depth,focus)));
    vec3 result=mix(center,sum/max(total,0.0001),blur*smoothstep(0.05,0.65,total));
    return mix(result,nearSum/max(nearTotal,0.0001),clamp(nearTotal,0.0,1.0));
}
