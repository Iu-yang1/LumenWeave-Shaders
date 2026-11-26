#version 330 compatibility
#include "/lib/grid.glsl"
in vec2 uv;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform ivec3 cameraPositionInt;
uniform ivec3 previousCameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 previousCameraPositionFract;
/* RENDERTARGETS: 4,5 */
layout(location=0) out vec4 historyColor;
layout(location=1) out vec4 historyGeometry;
/*
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA32F;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const vec4 colortex4ClearColor = vec4(0.0,0.0,0.0,0.0);
const vec4 colortex5ClearColor = vec4(0.0,0.0,0.0,0.0);
*/
vec3 viewAt(ivec2 p,float depth){
    vec4 v=gbufferProjectionInverse*vec4(outputUvAt(vec2(p))*2.0-1.0,depth*2.0-1.0,1.0);
    return v.xyz/v.w;
}
vec2 octEncode(vec3 n){
    n/=max(abs(n.x)+abs(n.y)+abs(n.z),1e-6);
    return n.z>=0.0?n.xy:(1.0-abs(n.yx))*mix(vec2(-1.0),vec2(1.0),greaterThanEqual(n.xy,vec2(0.0)));
}
vec3 octDecode(vec2 p){
    vec3 n=vec3(p,1.0-abs(p.x)-abs(p.y));
    if(n.z<0.0) n.xy=(1.0-abs(n.yx))*mix(vec2(-1.0),vec2(1.0),greaterThanEqual(n.xy,vec2(0.0)));
    return normalize(n);
}
void main(){
    ivec2 hi=ivec2(renderSize())-1;
    vec2 src=nativeUv(uv)*displaySize()-0.5;
    ivec2 p=clamp(ivec2(floor(src+0.5)),ivec2(0),hi);
    float depth=texelFetch(depthtex0,p,0).r;
    vec3 n=texelFetch(colortex1,p,0).xyz;
    vec4 current=texelFetch(colortex0,p,0);
    historyColor=vec4(current.rgb,0.0);
    historyGeometry=vec4(0.0);
    if(depth>=1.0 || dot(n,n)<0.5) return;
    vec3 view=viewAt(p,depth);
    float linearDepth=-view.z;
    float solid=texelFetch(depthtex1,p,0).r;
    float withoutHand=texelFetch(depthtex2,p,0).r;
    if(abs(depth-solid)>0.00001 || abs(solid-withoutHand)>0.00001 || current.a<0.99) return;
    // Four native samples reconstructed at the full-resolution output pixel.
    ivec2 base=ivec2(floor(src));
    vec2 frac=fract(src);
    vec3 sum=vec3(0.0),low=current.rgb,high=current.rgb;
    float weightSum=0.0;
    for(int y=0;y<2;++y)for(int x=0;x<2;++x){
        ivec2 donor=clamp(base+ivec2(x,y),ivec2(0),hi);
        float d=texelFetch(depthtex0,donor,0).r;
        if(d>=1.0 || abs(-viewAt(donor,d).z-linearDepth)>max(0.08,linearDepth*0.025)) continue;
        if(dot(n,texelFetch(colortex1,donor,0).xyz)<0.90) continue;
        vec2 w=mix(1.0-frac,frac,vec2(x,y));float weight=w.x*w.y;
        vec3 c=texelFetch(colortex0,donor,0).rgb;
        sum+=c*weight;weightSum+=weight;low=min(low,c);high=max(high,c);
    }
    vec3 resolved=weightSum>0.001?sum/weightSum:current.rgb;
    vec3 delta=vec3(cameraPositionInt-previousCameraPositionInt)+cameraPositionFract-previousCameraPositionFract;
    if(dot(delta,delta)<16.0){
        vec4 world=gbufferModelViewInverse*vec4(view,1.0);
        vec4 previous=gbufferPreviousModelView*vec4(world.xyz+delta,1.0);
        vec4 clip=gbufferPreviousProjection*previous;
        if(clip.w>0.0){
            vec2 prev=clip.xy/clip.w*0.5+0.5;
            if(all(greaterThan(prev,vec2(0)))&&all(lessThan(prev,vec2(1)))){
                ivec2 q=clamp(ivec2(prev*displaySize()),ivec2(0),ivec2(displaySize())-1);
                vec4 hist=texelFetch(colortex4,q,0),geom=texelFetch(colortex5,q,0);
                // Store both dimensions separately, avoiding float packing collisions.
                if(frameCounter>0 && all(equal(geom.zw,renderSize())) && hist.a>0.0 && abs(hist.a+previous.z)<=max(0.08,-previous.z*0.02) && dot(n,octDecode(geom.xy))>0.90){
                    float motion=length((prev-uv)*displaySize());
                    vec3 envelope=max((high-low)*0.25,vec3(0.005));
                    resolved=mix(resolved,clamp(hist.rgb,low-envelope,high+envelope),mix(0.88,0.5,smoothstep(1.0,12.0,motion)));
                }
            }
        }
    }
    historyColor=vec4(resolved,linearDepth);
    historyGeometry=vec4(octEncode(n),renderSize());
}
