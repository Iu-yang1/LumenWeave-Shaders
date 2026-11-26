#ifndef LW_HIZ_LIBRARY
#define LW_HIZ_LIBRARY
#ifdef LW_HIZ_ACTIVE
uniform sampler2D lwHiZ;
bool hizFrontAt(ivec2 tile,float rayDepth) {
    if(any(greaterThanEqual(tile,textureSize(lwHiZ,0)))) return false;
    vec2 bounds=texelFetch(lwHiZ,tile,0).rg;
#ifdef DISTANT_HORIZONS
    // If a native sky pixel is possible, DH must still be queried.
    if(bounds.y>=1.0) return false;
#endif
    return rayDepth+0.0000002<bounds.x;
}

bool hizRayInFront(vec2 uv,vec3 ray,ivec2 resolution,mat4 projection) {
    vec4 clip=projection*vec4(ray,1.0);
    float depth=clip.z/clip.w*0.5+0.5;
    ivec2 pixel=clamp(ivec2(uv*vec2(resolution)),ivec2(0),resolution-1);
    ivec2 coarse=pixel/16+ivec2(0,(resolution.y+3)/4);
    return hizFrontAt(coarse,depth) || hizFrontAt(pixel/4,depth);
}
#endif
#endif
