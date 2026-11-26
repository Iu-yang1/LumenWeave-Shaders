#version 430 core
#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_grid.glsl"
layout(local_size_x=8,local_size_y=8) in;
#if HIZ_MODE == 1
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.0625,0.0625);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.08375,0.08375);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.09375,0.09375);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.10625,0.10625);
#else
const vec2 workGroupsRender=vec2(0.125,0.125);
#endif
#else
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.25,0.25);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.335,0.335);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.375,0.375);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.425,0.425);
#else
const vec2 workGroupsRender=vec2(0.5,0.5);
#endif
#endif
#ifdef LW_HIZ_ACTIVE
#include "/lib/lighting/hiz_layout.glsl"
// Iris copies depthtex0 into depthtex1 immediately before deferred rendering.
// The one hierarchy represents both opaque and later translucent SSR.
uniform sampler2D depthtex0;
layout(rg32f) writeonly uniform image2D lwHiZImage;
shared vec2 ranges[64];
vec2 mergeRange(vec2 a,vec2 b) {return vec2(min(a.x,b.x),max(a.y,b.y));}
void writeRange(ivec2 p,int scale,ivec2 resolution,vec2 value) {
    if(any(greaterThanEqual(p,hizLevelSize(resolution,scale)))) return;
    imageStore(lwHiZImage,p+hizAtlasOffset(resolution,scale),vec4(value,0,0));
}
#if HIZ_MODE == 1
void main() {
    ivec2 resolution=lwRasterSize(depthtex0);
    ivec2 tile=ivec2(gl_WorkGroupID.xy);
    if(!hizAtlasFits(resolution,imageSize(lwHiZImage)) ||
       any(greaterThanEqual(tile,hizLevelSize(resolution,64)))) return;
    ivec2 base=tile*64+ivec2(gl_LocalInvocationID.xy);
    vec2 range=vec2(1,0);
    // Contiguous lanes access contiguous depth texels at every iteration.
    for(int y=0;y<8;++y) for(int x=0;x<8;++x) {
        ivec2 p=base+ivec2(x,y)*8;
        if(all(lessThan(p,resolution))) {
            float depth=texelFetch(depthtex0,p,0).r;
            range=mergeRange(range,vec2(depth));
        }
    }
    int i=int(gl_LocalInvocationIndex);
    ranges[i]=range;
    barrier();
    // 8 disjoint lane reductions then one final group reduction.
    if(i<8) {
        vec2 v=vec2(1,0);
        for(int j=0;j<8;++j) v=mergeRange(v,ranges[i*8+j]);
        ranges[i*8]=v;
    }
    barrier();
    if(i==0) {
        vec2 v=vec2(1,0);
        for(int j=0;j<8;++j) v=mergeRange(v,ranges[j*8]);
        writeRange(tile,64,resolution,v);
    }
}
#else
void main() {
    ivec2 resolution=lwRasterSize(depthtex0);
    if(!hizAtlasFits(resolution,imageSize(lwHiZImage))) return;
    ivec2 group=ivec2(gl_WorkGroupID.xy);
    ivec2 lane=ivec2(gl_LocalInvocationID.xy);
    ivec2 base=group*16+lane*2;
    vec2 range=vec2(1,0);
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=base+ivec2(x,y);
        if(all(lessThan(p,resolution))) {
            float a=texelFetch(depthtex0,p,0).r;
            range=mergeRange(range,vec2(a));
        }
    }
    int i=int(gl_LocalInvocationIndex);
    ranges[i]=range;
    barrier();
    if(all(equal(lane%2,ivec2(0)))) {
        vec2 fine=mergeRange(mergeRange(ranges[i],ranges[i+1]),
                             mergeRange(ranges[i+8],ranges[i+9]));
        ranges[i]=fine;
        writeRange(group*4+lane/2,4,resolution,fine);
    }
    barrier();
    if(i==0) {
        vec2 coarse=vec2(1,0);
        for(int y=0;y<8;y+=2) for(int x=0;x<8;x+=2)
            coarse=mergeRange(coarse,ranges[x+8*y]);
        writeRange(group,16,resolution,coarse);
    }
}
#endif
#else
void main(){}
#endif
