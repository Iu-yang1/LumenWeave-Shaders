#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const vec2 workGroupsRender = vec2(0.5,0.5);
#ifdef LW_HIZ_ACTIVE
uniform sampler2D depthtex0;
layout(rg32f) writeonly uniform image2D lwHiZImage;
shared vec2 bounds[64];
void main() {
    ivec2 fullSize=textureSize(depthtex0,0);
    ivec2 fineSize=(fullSize+3)/4;
    ivec2 coarseSize=(fullSize+15)/16;
    ivec2 group=ivec2(gl_WorkGroupID.xy);
    // 8x8 lanes each read a 2x2 quad from the 16x16 block.
    ivec2 lane=ivec2(gl_LocalInvocationID.xy);
    ivec2 base=group*16+lane*2;
    vec2 range=vec2(1.0,0.0);
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=base+ivec2(x,y);
        if(all(lessThan(p,fullSize))) {
            float d=texelFetch(depthtex0,p,0).r;
            range=vec2(min(range.x,d),max(range.y,d));
        }
    }
    bounds[gl_LocalInvocationIndex]=range;
    barrier();
    // Each 2x2 lane subgroup reduces its four 2x2 pixel quads.
    if(all(equal(lane%2,ivec2(0)))) {
        int i=int(gl_LocalInvocationIndex);
        vec2 a=bounds[i], b=bounds[i+1], c=bounds[i+8], d=bounds[i+9];
        vec2 fine=vec2(min(min(a.x,b.x),min(c.x,d.x)),max(max(a.y,b.y),max(c.y,d.y)));
        ivec2 tile=group*4+lane/2;
        if(all(lessThan(tile,fineSize)) && all(lessThan(tile,imageSize(lwHiZImage))))
            imageStore(lwHiZImage,tile,vec4(fine,0.0,0.0));
    }
    if(gl_LocalInvocationIndex==0u && all(lessThan(group,coarseSize))) {
        vec2 coarse=vec2(1.0,0.0);
        for(int i=0;i<64;++i) {
            coarse=vec2(min(coarse.x,bounds[i].x),max(coarse.y,bounds[i].y));
        }
        ivec2 p=group+ivec2(0,fineSize.y);
        if(all(lessThan(p,imageSize(lwHiZImage))))
            imageStore(lwHiZImage,p,vec4(coarse,0.0,0.0));
    }
}
#else
void main(){}
#endif
