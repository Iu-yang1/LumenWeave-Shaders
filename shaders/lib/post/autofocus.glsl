// Original LumenWeave estimator. One invocation per frame.
#include "/lib/post/camera_depth.glsl"
float lwAutofocusTarget(){
    float samples[9];
    vec2 resolution=vec2(lwRasterSize(depthtex2));
    vec2 radius=vec2(max(resolution.y*0.012*DOF_AF_AREA,2.0))/resolution;
    float center=1.0/clamp(lwWorldFocusDepth(vec2(0.5)),0.65,512.0);
    int index=0,support=0;
    for(int y=-1;y<=1;++y)for(int x=-1;x<=1;++x){
        float d=1.0/clamp(lwWorldFocusDepth(vec2(0.5)+vec2(x,y)*radius),0.65,512.0);
        samples[index++]=d;
        if(abs(d-center)<max(0.004,center*0.22)) ++support;
    }
    // Median rejects isolated leaves, edge samples and accidental foreground.
    for(int i=1;i<9;++i){
        float v=samples[i];int j=i-1;
        while(j>=0){if(samples[j]<=v) break;samples[j+1]=samples[j];--j;}
        samples[j+1]=v;
    }
    // Honor a deliberate reticle target when at least two neighbours agree.
    return support>=3?center:samples[4];
}
vec4 lwAdvanceFocus(vec4 previous,float dt){
    float target=lwAutofocusTarget();
    if(previous.a<0.5) return vec4(target,target,0.0,1.0);
    // Smooth optical power (1/distance), not nonlinear hardware Z or metres.
    float old=previous.r;
    float band=max(0.0025,old*0.035);
    float delta=target-old;
    float requested=old+sign(delta)*max(abs(delta)-band,0.0);
    float halfLife=DOF_AF_SPEED*(requested>old?0.8:1.35);
    float next=mix(requested,old,exp2(-clamp(dt,0.0,0.25)/halfLife));
    return vec4(clamp(next,1.0/512.0,1.0/0.65),target,0.0,1.0);
}
