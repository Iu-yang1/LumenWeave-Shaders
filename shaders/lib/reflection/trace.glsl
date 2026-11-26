#ifndef LW_REFLECTION_TRACE
#define LW_REFLECTION_TRACE
#ifndef LW_REFLECTION_DEPTH
#define LW_REFLECTION_DEPTH depthtex1
#define LW_REFLECTION_DH_DEPTH dhDepthTex1
#endif
uniform sampler2D colortex8;
uniform mat4 gbufferProjection;
#ifdef DISTANT_HORIZONS
uniform sampler2D LW_REFLECTION_DH_DEPTH;
uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
#endif

bool insideScreen(vec2 uv) {
    return all(greaterThan(uv,vec2(0.0))) && all(lessThan(uv,vec2(1.0)));
}

vec2 reflectionProjectedUv(vec3 ray,mat4 projection) {
    vec4 clip=projection*vec4(ray,1.0);
    vec2 uv=clip.xy/clip.w*0.5+0.5;
#ifdef LW_TAA_ACTIVE
    uv+=jitterOffset(frameCounter);
#endif
    return uv;
}

vec3 reflectionNativePosition(vec2 pixelUv,float depth,vec2 targetUv) {
#ifdef LW_REFLECTION_OWNER
    int owner=sampleOwner(pixelUv,depth,false);
    vec3 position=reconstructProjection(pixelUv,depth,gbufferProjectionInverse,owner!=0);
    if(owner==1) {
        vec3 normal=transpose(mat3(gbufferModelViewInverse))*decodeNormal(texelFetch(colortex1,depthPixelAtUv(colortex1,pixelUv),0).xy);
        position=stableViewSurfacePosition(position,unjitteredUv(targetUv,true),normal,gbufferProjectionInverse);
    }
    return position;
#else
    return reconstructViewPosition(pixelUv,depth);
#endif
}

bool reflectionRayDepth(vec3 ray,out vec2 uv,out float delta,out int kind) {
    uv=reflectionProjectedUv(ray,gbufferProjection);
    kind=0;
    if(!insideScreen(uv)) return false;
    ivec2 pixel=depthPixelAtUv(LW_REFLECTION_DEPTH,uv);
    float depth=texelFetch(LW_REFLECTION_DEPTH,pixel,0).r;
    if(depth<1.0) {
        vec2 pixelUv=depthPixelUv(LW_REFLECTION_DEPTH,pixel);
        delta=reflectionNativePosition(pixelUv,depth,uv).z-ray.z;
        kind=1;
        return true;
    }
#ifdef DISTANT_HORIZONS
    vec2 distantUv=reflectionProjectedUv(ray,dhProjection);
    if(insideScreen(distantUv)) {
        ivec2 dhPixel=depthPixelAtUv(LW_REFLECTION_DH_DEPTH,distantUv);
        float dhDepth=texelFetch(LW_REFLECTION_DH_DEPTH,dhPixel,0).r;
        if(dhDepth<1.0) {
            vec2 pixelUv=depthPixelUv(LW_REFLECTION_DH_DEPTH,dhPixel);
            vec3 position=reconstructProjection(pixelUv,dhDepth,dhProjectionInverse,true);
            uv=distantUv;delta=position.z-ray.z;kind=2;
            return true;
        }
    }
#endif
    delta=-1.0;
    return true;
}

vec4 traceScreenReflection(vec3 origin,vec3 direction,int steps,out vec2 hitUv,out float hitTravel,out int hitKind) {
    float travel=0.30;
    float maxTravel=steps<=8 ? 12.0 : 48.0;
    float stepRatio=pow((maxTravel+1.0)/1.30,1.0/float(max(steps-1,1)));
    float previousTravel=0.0;
    bool previousFront=false;
    hitUv=vec2(0.0);hitTravel=0.0;hitKind=0;
    for(int tap=0;tap<steps;++tap) {
        vec3 ray=origin+direction*travel;
        if(ray.z> -0.12 || travel>maxTravel+0.001) break;
        vec2 uv;float delta;int kind;
        if(!reflectionRayDepth(ray,uv,delta,kind)) break;
        if(previousFront && delta>=0.0 && kind!=0) {
            float lo=previousTravel,hi=travel;
            for(int refine=0;refine<5;++refine) {
                float mid=(lo+hi)*0.5;
                vec2 midUv;float midDelta;int midKind;
                if(!reflectionRayDepth(origin+direction*mid,midUv,midDelta,midKind) || midDelta<0.0 || midKind==0) {
                    lo=mid;
                } else {
                    hi=mid;uv=midUv;delta=midDelta;kind=midKind;
                }
            }
            float thickness=0.20+hi*0.035;
            if(delta<thickness && hi>0.12) {
                vec2 edge=min(uv,1.0-uv);
                float confidence=smoothstep(0.0,0.08,min(edge.x,edge.y));
                confidence*=1.0-smoothstep(18.0,48.0,hi);
                confidence*=1.0-smoothstep(thickness*0.65,thickness,delta);
                hitUv=uv;hitTravel=hi;hitKind=kind;
                return vec4(texture(colortex8,uv).rgb,confidence);
            }
        }
        previousFront=delta<0.0;previousTravel=travel;
        travel=(travel+1.0)*stepRatio-1.0;
    }
    return vec4(0.0);
}

vec4 traceScreenReflection(vec3 origin,vec3 direction,int steps) {
    vec2 unusedUv;float unusedTravel;int unusedKind;
    return traceScreenReflection(origin,direction,steps,unusedUv,unusedTravel,unusedKind);
}
#endif
