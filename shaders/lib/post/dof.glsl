#include "/lib/coordinates/raster_grid.glsl"
// Linear view depth and signed circle of confusion, in pixels.
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform bool firstPersonCamera;
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
    float depth=lwPostDepth(depthtex0,uv);
    // The hand has a compressed projection and is absent from depthtex2.
    // Keep close world geometry when the solid depth agrees.
    float solid=lwPostDepth(depthtex1,uv);
    float withoutHand=lwPostDepth(depthtex2,uv);
    if(firstPersonCamera && depth<0.55 && (solid+0.00001<withoutHand || depth+0.00001<solid)) return -1.0;
#ifdef DISTANT_HORIZONS
    if(depth>=1.0) {
        float distant=lwPostDepth(dhDepthTex0,uv);
        if(distant<1.0) return lwLinearDepth(dhProjectionInverse,distant);
    }
#endif
    return depth>=1.0?512.0:lwLinearDepth(gbufferProjectionInverse,depth);
}
float lwFocusDepth(){
#if DOF_MODE == 2
    return DOF_FOCUS;
#else
#ifdef LW_GEOMETRY_TAAU
    // Loader centerDepthSmooth observes the storage center, not active grid.
    float depth=clamp(lwPostDepth(depthtex0,vec2(0.5)),0.55,0.99999);
#else
    float depth=clamp(centerDepthSmooth,0.55,0.99999);
#endif
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
    if(depth<=0.0) return center;
    vec2 texel=1.0/vec2(textureSize(source,0));
    const vec2 taps[8]=vec2[8](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1),vec2(0.707,0.707),vec2(-0.707,0.707),vec2(0.707,-0.707),vec2(-0.707,-0.707));
    vec3 farSum=center,nearSum=vec3(0.0);
    float farTotal=1.0,nearTotal=0.0;
    float focus=lwFocusDepth();
    // Separate foreground dilation from the background disk. A foreground
    // donor may cover a sharp background pixel; the reverse is forbidden.
    for(int i=0;i<8;++i) {
        if(abs(coc)>0.65) {
            vec2 p=clamp(uv+taps[i]*texel*abs(coc),texel*0.5,1.0-texel*0.5);
            float d=lwDofDepth(p);
            if(d>0.0) {
                float w=1.0-smoothstep(0.04,0.23,abs(d-depth)/max(depth,0.5));
                farSum+=texture(source,p).rgb*w;farTotal+=w;
            }
        }
        for(int ring=0;ring<2;++ring) {
            float distancePixels=ring==0?4.0:10.0;
            vec2 p=clamp(uv+taps[i]*texel*distancePixels,texel*0.5,1.0-texel*0.5);
            float d=lwDofDepth(p);
            if(d<=0.0 || d>=depth*0.97) continue;
            float cover=smoothstep(distancePixels-1.5,distancePixels+1.5,-lwCoC(d,focus));
            if(cover<=0.0) continue;
            nearSum+=texture(source,p).rgb*cover;nearTotal+=cover;
        }
    }
    vec3 farColor=farSum/farTotal;
    return mix(farColor,nearSum/max(nearTotal,0.0001),clamp(nearTotal*0.125,0.0,1.0));
}
