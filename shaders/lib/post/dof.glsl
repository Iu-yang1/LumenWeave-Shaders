// Linear view depth and signed circle of confusion, in pixels.
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform float centerDepthSmooth;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif
float lwLinearDepth(mat4 inverseProjection,float depth) {
    vec4 p=inverseProjection*vec4(0.0,0.0,depth*2.0-1.0,1.0);
    return clamp(-p.z/max(abs(p.w),0.00001),0.05,512.0);
}
float lwDofDepth(vec2 uv) {
    float depth=texture(depthtex0,uv).r;
    if(depth<0.55) return -1.0;
#ifdef DISTANT_HORIZONS
    if(depth>=1.0) {
        float distant=texture(dhDepthTex0,uv).r;
        if(distant<1.0) return lwLinearDepth(dhProjectionInverse,distant);
    }
#endif
    return depth>=1.0?512.0:lwLinearDepth(gbufferProjectionInverse,depth);
}
float lwFocusDepth(){
#if DOF_MODE == 2
    return DOF_FOCUS;
#else
    float depth=clamp(centerDepthSmooth,0.55,0.99999);
    return clamp(lwLinearDepth(gbufferProjectionInverse,depth),1.0,64.0);
#endif
}
float lwCoC(float depth,float focus) {
    if(depth<=0.0) return 0.0;
    float strength=DOF_STRENGTH;
#if DOF_MODE == 3
    strength*=1.8;
#endif
    return clamp((1.0/focus-1.0/depth)*48.0*strength,-14.0,14.0);
}
vec3 lwDofGather(sampler2D source,vec2 uv,vec3 center,float depth,float coc) {
    if(abs(coc)<0.65) return center;
    vec2 texel=1.0/vec2(textureSize(source,0));
    const vec2 taps[8]=vec2[8](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1),vec2(0.707,0.707),vec2(-0.707,0.707),vec2(0.707,-0.707),vec2(-0.707,-0.707));
    vec3 sum=center;float total=1.0;
    for(int i=0;i<8;++i) {
        vec2 p=clamp(uv+taps[i]*texel*abs(coc),texel*0.5,1.0-texel*0.5);
        float d=lwDofDepth(p);
        if(d<=0.0) continue;
        float w=1.0-smoothstep(0.04,0.23,abs(d-depth)/max(depth,0.5));
        sum+=texture(source,p).rgb*w;total+=w;
    }
    return sum/total;
}
