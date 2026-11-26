#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=16) in;
const vec2 workGroupsRender=vec2(0.5,0.5);
#ifdef LW_DOF_TILE_FUSION
/*
const int colortex10Format = RGBA16F;
*/
layout(rgba16f) writeonly uniform image2D colorimg10;
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_DOF_TILE_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_DOF_TILE_SOURCE colortex0
#ifdef LW_STATIC_HDR_REUSE
uniform sampler2D colortex4;
#include "/lib/post/motion_state.glsl"
#endif
#endif
#include "/lib/post/dof.glsl"

// The horizontal pass is cached only for this tile plus a vertical halo.
// Far-out donors (large displays) use the identical horizontal function.
const int LW_DOF_TILE_WIDTH=8;
const int LW_DOF_TILE_HEIGHT=16;
const int LW_DOF_TILE_MAX_HALO=16;
shared vec4 lwDofHorizontal[LW_DOF_TILE_WIDTH*(LW_DOF_TILE_HEIGHT+2*LW_DOF_TILE_MAX_HALO)];

vec4 lwDofHorizontalAt(sampler2D source,ivec2 p,ivec2 size,float focus){
    p=clamp(p,ivec2(0),size-1);
    vec2 uv=(vec2(p)+0.5)/vec2(size);
    float depth=lwDofDepth(uv);
    vec3 center=textureLod(source,uv,0.0).rgb;
    vec4 value=vec4(lwDofAxisGather(source,uv,vec4(center,depth),focus,vec2(1,0),false),depth);
    // Preserve the RGBA16F store/load boundary of the old horizontal pass.
    return vec4(unpackHalf2x16(packHalf2x16(value.xy)),
                unpackHalf2x16(packHalf2x16(value.zw)));
}

vec4 lwDofTileDonor(sampler2D source,ivec2 p,ivec2 size,ivec2 base,int halo,float focus){
    p=clamp(p,ivec2(0),size-1);
    ivec2 local=p-base+ivec2(0,halo);
    if(local.x>=0 && local.x<LW_DOF_TILE_WIDTH && local.y>=0 && local.y<LW_DOF_TILE_HEIGHT+2*halo)
        return lwDofHorizontal[local.x+local.y*LW_DOF_TILE_WIDTH];
    return lwDofHorizontalAt(source,p,size,focus);
}

vec3 lwDofVertical(sampler2D source,ivec2 p,ivec2 size,ivec2 base,int halo,vec4 center,float focus){
    float depth=center.a;
    if(depth<=0.0) return center.rgb;
    vec2 uv=(vec2(p)+0.5)/vec2(size);
    vec2 pixel=1.0/max(vec2(viewWidth,viewHeight),vec2(1.0));
    float coc=lwCoC(depth,focus);
    float radius=max(abs(coc),2.5*viewHeight/1080.0);
    float blur=smoothstep(0.15,1.5,abs(coc));
#if DOF_QUALITY == 0
    const int pairs=1;
#elif DOF_QUALITY == 1
    const int pairs=2;
#else
    const int pairs=3;
#endif
    vec3 sum=center.rgb,nearSum=vec3(0.0);
    float total=1.0,nearTotal=0.0;
    float inverseDepth=1.0/max(depth,0.5);
    float nearLimit=depth*0.97;
    for(int i=-pairs;i<=pairs;++i){
        if(i==0)continue;
        float t=float(i)/float(pairs);
        vec2 q=clamp(uv+vec2(0,1)*pixel*(radius*t),pixel*0.5,1.0-pixel*0.5);
        ivec2 donorPixel=clamp(ivec2(q*vec2(size)),ivec2(0),size-1);
        vec4 donor=lwDofTileDonor(source,donorPixel,size,base,halo,focus);
        if(donor.a<=0.0)continue;
        float weight=1.0/(1.0+4.0*t*t);
        float compatibility=1.0-smoothstep(0.04,0.23,abs(donor.a-depth)*inverseDepth);
        float farWeight=weight*compatibility*blur;
        sum+=donor.rgb*farWeight;total+=farWeight;
        if(donor.a<nearLimit){
            float distancePixels=abs(radius*t);
            float cover=weight*smoothstep(max(distancePixels-1.0,0.0),distancePixels+1.0,-lwCoC(donor.a,focus));
            nearSum+=donor.rgb*cover;nearTotal+=cover;
        }
    }
    return mix(sum/total,nearSum/max(nearTotal,0.0001),clamp(nearTotal/float(pairs),0.0,1.0));
}

void lwDofTile(sampler2D source){
    ivec2 size=imageSize(colorimg10);
    ivec2 base=ivec2(gl_WorkGroupID.xy)*ivec2(LW_DOF_TILE_WIDTH,LW_DOF_TILE_HEIGHT);
    int halo=min(LW_DOF_TILE_MAX_HALO,int(ceil(8.0*float(size.y)/1080.0))+1);
    int entries=LW_DOF_TILE_WIDTH*(LW_DOF_TILE_HEIGHT+2*halo);
    int lane=int(gl_LocalInvocationIndex);
    float focus=lwFocusDepth();
    for(int i=lane;i<entries;i+=LW_DOF_TILE_WIDTH*LW_DOF_TILE_HEIGHT){
        ivec2 p=base+ivec2(i%LW_DOF_TILE_WIDTH,i/LW_DOF_TILE_WIDTH-halo);
        lwDofHorizontal[i]=lwDofHorizontalAt(source,p,size,focus);
    }
    barrier();
    ivec2 p=base+ivec2(gl_LocalInvocationID.xy);
    // Partial edge groups must reach the shared barrier before exiting.
    if(any(greaterThanEqual(p,size))) return;
    vec4 center=lwDofHorizontal[lane+halo*LW_DOF_TILE_WIDTH];
    imageStore(colorimg10,p,vec4(lwDofVertical(source,p,size,base,halo,center,focus),center.a));
}

void main(){
#ifdef LW_STATIC_HDR_REUSE
    if(lwMotionIsIdentity()) lwDofTile(colortex4);
    else
#endif
    lwDofTile(LW_DOF_TILE_SOURCE);
}
#else
void main(){}
#endif
