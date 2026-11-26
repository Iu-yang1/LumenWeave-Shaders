#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const vec2 workGroupsRender=vec2(0.5,0.5);
#ifdef LW_HIZ_ACTIVE
#include "/lib/lighting/hiz_layout.glsl"
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
layout(rg32f) writeonly uniform image2D lwHiZImage;
shared vec4 ranges[64];
vec4 mergeRange(vec4 a,vec4 b) {
    return vec4(min(a.x,b.x),max(a.y,b.y),min(a.z,b.z),max(a.w,b.w));
}
void writeRange(ivec2 p,int scale,ivec2 resolution,vec4 value) {
    if(any(greaterThanEqual(p,hizLevelSize(resolution,scale)))) return;
    imageStore(lwHiZImage,p+hizAtlasOffset(resolution,scale,false),vec4(value.xy,0,0));
    imageStore(lwHiZImage,p+hizAtlasOffset(resolution,scale,true),vec4(value.zw,0,0));
}
void main() {
    ivec2 resolution=textureSize(depthtex0,0);
    if(!hizAtlasFits(resolution,imageSize(lwHiZImage))) return;
    ivec2 group=ivec2(gl_WorkGroupID.xy);
    ivec2 lane=ivec2(gl_LocalInvocationID.xy);
    ivec2 base=group*16+lane*2;
    vec4 range=vec4(1,0,1,0);
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=base+ivec2(x,y);
        if(all(lessThan(p,resolution))) {
            float a=texelFetch(depthtex0,p,0).r;
            float b=texelFetch(depthtex1,p,0).r;
            range=mergeRange(range,vec4(a,a,b,b));
        }
    }
    int i=int(gl_LocalInvocationIndex);
    ranges[i]=range;
    barrier();
    if(all(equal(lane%2,ivec2(0)))) {
        vec4 fine=mergeRange(mergeRange(ranges[i],ranges[i+1]),
                              mergeRange(ranges[i+8],ranges[i+9]));
        ranges[i]=fine;
        writeRange(group*4+lane/2,4,resolution,fine);
    }
    barrier();
    if(i==0) {
        vec4 coarse=vec4(1,0,1,0);
        for(int y=0;y<8;y+=2) for(int x=0;x<8;x+=2)
            coarse=mergeRange(coarse,ranges[x+8*y]);
        writeRange(group,16,resolution,coarse);
    }
}
#else
void main(){}
#endif
