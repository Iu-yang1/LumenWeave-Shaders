#include "/lib/quality.glsl"
layout(local_size_x=16,local_size_y=16) in;
const ivec3 workGroups=ivec3(8,8,1);
#ifdef LW_CLOUD_CACHE_ACTIVE
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;
#include "/lib/atmosphere/cloud_noise.glsl"
#include "/lib/atmosphere/cloud_cache.glsl"
layout(rg16f) uniform image2D lwCloudShapeImage;
shared ivec2 previousOrigin;
shared bool previousValid;
void main() {
    ivec2 lane=ivec2(gl_GlobalInvocationID.xy);
    ivec2 origin=cloudCacheOrigin();
    if(gl_LocalInvocationIndex==0u) {
        previousValid=imageLoad(lwCloudShapeImage,ivec2(512,2)).r>0.5;
        previousOrigin=ivec2(0);
        if(previousValid) previousOrigin=ivec2(cloudDecode(imageLoad(lwCloudShapeImage,ivec2(512,0)).rg),
                    cloudDecode(imageLoad(lwCloudShapeImage,ivec2(512,1)).rg));
    }
    barrier();
    if(previousValid && all(equal(origin,previousOrigin))) return;
    bool valid=previousValid;
    ivec2 old=previousOrigin;
    // Stable views dispatch only 64 groups. On a snapped shift, each
    // invocation handles disjoint cells; overlapping ring cells need no writes.
    for(int y=lane.y;y<512;y+=128) for(int x=lane.x;x<512;x+=128) {
        ivec2 p=ivec2(x,y);
        ivec2 cell=cloudCellForPixel(p,origin);
        if(valid && all(greaterThanEqual(cell,old)) && all(lessThan(cell,old+ivec2(512)))) continue;
        vec2 uv=vec2(cell)*3.0*0.017;
        vec2 shape=vec2(0.65*cloudNoise(uv)+0.25*cloudNoise(uv*2.07),0.10*cloudNoise(uv*5.0));
        imageStore(lwCloudShapeImage,p,vec4(shape,0,0));
    }
}
#else
void main(){}
#endif
