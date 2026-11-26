#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const vec2 workGroupsRender=vec2(0.5,0.5);
#ifdef LW_SSR_HALF
#include "/lib/lighting/overworld.glsl"
uniform sampler2D colortex0;
#include "/lib/reflection/material_trace.glsl"
layout(rgba16f) writeonly uniform image2D colorimg9;
void main(){
    ivec2 p=ivec2(gl_GlobalInvocationID.xy),size=imageSize(colorimg9);
    if(any(greaterThanEqual(p,size))) return;
    ivec2 fullSize=textureSize(depthtex0,0);
    ivec2 donor=clamp(ivec2((vec2(p)+0.5)*vec2(fullSize)/vec2(size)),ivec2(0),fullSize-1);
    vec4 result=vec4(0.0);
    vec4 metadata=texelFetch(colortex12,donor,0);
    float depth=texelFetch(depthtex0,donor,0).r;
    vec4 materialDepth=texelFetch(colortex2,donor,0);
    if(metadata.a>=0.28 && max(metadata.r,max(metadata.g,metadata.b))>0.001 && depth<1.0 && abs(depth-materialDepth.x)<=0.00000012) {
        vec4 geometry=texelFetch(colortex1,donor,0);
        vec3 normal=decodeNormal(geometry.xy);
        vec3 position=reconstructViewPosition(depthPixelUv(depthtex0,donor),depth);
        result=traceMaterialCorrection(donor,position,normal,geometry,materialDepth,metadata);
    }
    imageStore(colorimg9,p,result);
}
#else
void main(){}
#endif
