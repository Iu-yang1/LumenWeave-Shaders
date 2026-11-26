#ifndef LW_HIZ_LIBRARY
#define LW_HIZ_LIBRARY
#ifdef LW_HIZ_ACTIVE
#include "/lib/lighting/hiz_layout.glsl"
uniform sampler2D lwHiZ;

// Cheap bounded interval rejection. Perspective coordinates and device depth
// are monotone over a positive-w segment. One tile contains the entire segment.
bool hizRejectInterval(vec4 a,vec4 b,ivec2 resolution,bool dhFallback) {
    if(a.w<=0.0 || b.w<=0.0 || !hizAtlasFits(resolution,textureSize(lwHiZ,0))) return false;
    vec2 p=(a.xy/a.w*0.5+0.5)*vec2(resolution);
    vec2 q=(b.xy/b.w*0.5+0.5)*vec2(resolution);
    if(any(lessThan(min(p,q),vec2(0))) || any(greaterThanEqual(max(p,q),vec2(resolution)))) return false;
    ivec2 first=ivec2(p)/64,last=ivec2(q)/64;
    if(any(notEqual(first,last))) return false;
    vec2 bounds=texelFetch(lwHiZ,first+hizAtlasOffset(resolution,64),0).rg;
    if(dhFallback && bounds.y>=1.0) return false;
    float rayDepth=max(a.z/a.w,b.z/b.w)*0.5+0.5;
    return rayDepth+0.0000002<bounds.x;
}

#if HIZ_MODE == 2

float hizProjectedDepth(vec4 clip) { return clip.z/clip.w*0.5+0.5; }

// Solve (c.xy+t*d.xy)/(c.w+t*d.w)=boundaryNdc exactly.
float hizCrossing(float c,float d,float w,float dw,float ndc,float limit) {
    float denom=d-ndc*dw;
    return abs(denom)>1e-8 ? (ndc*w-c)/denom : limit;
}
float hizTileExit(vec4 c,vec4 d,ivec2 tile,int scale,ivec2 resolution,
                  vec2 velocity,float t,float limit) {
    vec2 lower=vec2(tile*scale);
    vec2 upper=min(lower+float(scale),vec2(resolution));
    vec2 edge=mix(lower,upper,greaterThan(velocity,vec2(0)));
    vec2 ndc=edge/vec2(resolution)*2.0-1.0;
    float x=abs(velocity.x)>1e-8 ? hizCrossing(c.x,d.x,c.w,d.w,ndc.x,limit) : limit;
    float y=abs(velocity.y)>1e-8 ? hizCrossing(c.y,d.y,c.w,d.w,ndc.y,limit) : limit;
    float epsilon=max(0.000001,abs(t)*0.0000002);
    if(x<t-epsilon) x=limit;
    if(y<t-epsilon) y=limit;
    return min(limit,max(t+epsilon,min(x,y)));
}

// 1 exact native pixel candidate, 0 complete native miss, -1 use original
// traversal (budget exhaustion, invalid atlas, or DH sky ownership).
int hizTrace(sampler2D depthBuffer,mat4 projection,mat4 inverseProjection,
             vec3 origin,vec3 direction,float start,float limit,int budget,
             bool dhFallback,bool requireFront,
             out ivec2 hitPixel,out float hitTravel,out float hitDelta) {
    ivec2 resolution=textureSize(depthBuffer,0);
    hitPixel=ivec2(0);hitTravel=0.0;hitDelta=0.0;
    if(!hizAtlasFits(resolution,textureSize(lwHiZ,0))) return -1;
    vec4 c=projection*vec4(origin,1);
    vec4 d=projection*vec4(direction,0);
    if(direction.z>0.0) limit=min(limit,(-0.12-origin.z)/direction.z);
    vec2 velocity=d.xy*c.w-c.xy*d.w;
    float t=start;
    bool frontSeen=!requireFront;
    for(int visit=0;visit<budget;++visit) {
        if(t>=limit) return 0;
        vec4 p=c+d*t;
        if(p.w<=0.0) return 0;
        vec2 uv=p.xy/p.w*0.5+0.5;
        vec2 pixelPosition=uv*vec2(resolution)+sign(velocity)*0.0001;
        if(any(lessThan(pixelPosition,vec2(0))) ||
           any(greaterThanEqual(pixelPosition,vec2(resolution)))) return 0;
        ivec2 pixel=ivec2(floor(pixelPosition));
        bool skipped=false;
        for(int scale=64;scale>=4;scale/=4) {
            ivec2 tile=pixel/scale;
            vec2 bounds=texelFetch(lwHiZ,tile+hizAtlasOffset(resolution,scale),0).rg;
            if(dhFallback && bounds.y>=1.0) continue;
            float end=hizTileExit(c,d,tile,scale,resolution,velocity,t,limit);
            float rayDepth=max(hizProjectedDepth(p),hizProjectedDepth(c+d*end));
            if(bounds.x>=1.0 || rayDepth+0.0000002<bounds.x) {
                frontSeen=true;t=end;skipped=true;break;
            }
        }
        if(skipped) continue;
        float end=hizTileExit(c,d,pixel,1,resolution,velocity,t,limit);
        float depth=texelFetch(depthBuffer,pixel,0).r;
        if(depth>=1.0) {
            if(dhFallback) return -1;
            frontSeen=true;t=end;continue;
        }
        vec2 center=(vec2(pixel)+0.5)/vec2(resolution);
        vec4 surface=inverseProjection*vec4(center*2.0-1.0,depth*2.0-1.0,1);
        float z=surface.z/surface.w;
        float a=z-(origin.z+direction.z*t);
        float b=z-(origin.z+direction.z*end);
        if(a<0.0) frontSeen=true;
        if((a>=0.0 && frontSeen) || (a<0.0 && b>=0.0)) {
            hitPixel=pixel;
            hitTravel=a>=0.0 ? t : mix(t,end,clamp(-a/max(b-a,1e-8),0.0,1.0));
            hitDelta=max(z-(origin.z+direction.z*hitTravel),0.0);
            return 1;
        }
        if(b<0.0) frontSeen=true;
        t=end;
    }
    return t>=limit ? 0 : -1;
}
#endif // full traversal
#endif
#endif
