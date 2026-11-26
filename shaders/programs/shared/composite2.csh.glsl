#include "/lib/quality.glsl"
layout(local_size_x=16,local_size_y=16) in;
const vec2 workGroupsRender=vec2(1.0,1.0);
#ifdef LW_MOTION_DOF_FUSED
uniform sampler2D colortex4;
layout(rgba16f) writeonly uniform image2D colorimg0;
layout(rgba16f) writeonly uniform image2D colorimg10;
/* const int colortex10Format = RGBA16F; */
#include "/lib/post/motion_blur.glsl"
shared vec4 lwMotionTile[256];
shared bool lwTileMoving;
vec3 lwMotionPixel(sampler2D source,ivec2 p,ivec2 size){
    p=clamp(p,ivec2(0),size-1);
    vec2 uv=(vec2(p)+0.5)/vec2(size);
    vec3 center=texelFetch(source,p,0).rgb;
    vec3 c=lwMotionBlur(source,uv,center,lwTileMoving);
    return vec3(unpackHalf2x16(packHalf2x16(c.xy)),unpackHalf2x16(packHalf2x16(vec2(c.z,0.0))).x);
}
vec3 lwMotionDonor(sampler2D source,ivec2 p,ivec2 size){
    p=clamp(p,ivec2(0),size-1);
    ivec2 local=p-ivec2(gl_WorkGroupID.xy)*16;
    if(all(greaterThanEqual(local,ivec2(0))) && all(lessThan(local,ivec2(16))))
        return lwMotionTile[local.x+local.y*16].rgb;
    // A cross-tile donor cannot read concurrently written colorimg0.
    // Reconstruct only the necessary edge donor from immutable TAA RGB.
    return lwMotionPixel(source,p,size);
}
vec3 lwMotionTileSample(sampler2D source,vec2 uv){
    if(!lwTileMoving) return textureLod(source,uv,0.0).rgb;
    ivec2 size=textureSize(source,0);
    vec2 pos=uv*vec2(size)-0.5;
    ivec2 p=ivec2(floor(pos));
    vec2 f=fract(pos);
    vec3 a=lwMotionDonor(source,p,size);
    if(f.x==0.0 && f.y==0.0) return a;
    vec3 b=lwMotionDonor(source,p+ivec2(1,0),size);
    vec3 c=lwMotionDonor(source,p+ivec2(0,1),size);
    vec3 d=lwMotionDonor(source,p+ivec2(1,1),size);
    return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
#define LW_DOF_COLOR(source,uv) lwMotionTileSample(source,uv)
#include "/lib/post/dof.glsl"
void main(){
    ivec2 size=imageSize(colorimg0);
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    uint lane=gl_LocalInvocationIndex;
    if(lane==0u) lwTileMoving=!lwMotionIsIdentity();
    barrier();
    if(lwTileMoving) {
        vec3 color=lwMotionPixel(colortex4,p,size);
        lwMotionTile[lane]=vec4(color,1.0);
        if(all(lessThan(p,size))) imageStore(colorimg0,p,vec4(color,1.0));
    }
    barrier();
    // Exactly one invocation owns each half-resolution output texel.
    // Use the real half attachment size for odd display dimensions.
    ivec2 halfSize=imageSize(colorimg10),h=p/2;
    if(any(notEqual(p%2,ivec2(0))) || any(greaterThanEqual(h,halfSize))) return;
    vec2 uv=(vec2(h)+0.5)/vec2(halfSize);
    float focus=lwFocusDepth(),depth=lwDofDepth(uv);
    vec3 center=lwMotionTileSample(colortex4,uv);
    vec3 color=lwDofGather(colortex4,uv,center,depth,lwCoC(depth,focus),focus);
    imageStore(colorimg10,h,vec4(color,depth));
}
#else
void main(){}
#endif
