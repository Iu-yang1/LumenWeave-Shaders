#version 430 core
#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_grid.glsl"
layout(local_size_x=8,local_size_y=8) in;
#if defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 50
const vec2 workGroupsRender=vec2(0.0078125,0.0078125);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 67
const vec2 workGroupsRender=vec2(0.01046875,0.01046875);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 75
const vec2 workGroupsRender=vec2(0.01171875,0.01171875);
#elif defined(LW_GEOMETRY_TAAU) && GEOMETRY_TAAU_SCALE == 85
const vec2 workGroupsRender=vec2(0.01328125,0.01328125);
#else
const vec2 workGroupsRender=vec2(0.015625,0.015625);
#endif
#if defined(LW_HIZ_ACTIVE) && HIZ_MODE == 2
#include "/lib/lighting/hiz_layout.glsl"
uniform sampler2D depthtex0;
layout(rg32f) uniform image2D lwHiZImage;
void main() {
    ivec2 resolution=lwRasterSize(depthtex0);
    ivec2 tile=ivec2(gl_GlobalInvocationID.xy);
    if(!hizAtlasFits(resolution,imageSize(lwHiZImage)) ||
        any(greaterThanEqual(tile,hizLevelSize(resolution,64)))) return;
    vec2 range=vec2(1,0);
    for(int y=0;y<4;++y) for(int x=0;x<4;++x) {
        ivec2 p=tile*4+ivec2(x,y);
        if(all(lessThan(p,hizLevelSize(resolution,16)))) {
            vec2 b=imageLoad(lwHiZImage,p+hizAtlasOffset(resolution,16)).rg;
            range=vec2(min(range.x,b.x),max(range.y,b.y));
        }
    }
    imageStore(lwHiZImage,tile+hizAtlasOffset(resolution,64),vec4(range,0,0));
}
#else
void main(){}
#endif
