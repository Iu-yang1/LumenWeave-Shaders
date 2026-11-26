#ifndef LW_VOLUME_DEPTH
#define LW_VOLUME_DEPTH
#include "/lib/coordinates/reconstruct.glsl"
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#include "/lib/materials/geometry_buffer.glsl"
uniform sampler2D colortex1;
#endif
uniform sampler2D depthtex0;
uniform int isEyeInWater;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif

void volumeRay(vec2 uv,out vec3 direction,out float distanceToSurface) {
    ivec2 pixel=depthPixelAtUv(depthtex0,uv);
    float depth=texelFetch(depthtex0,pixel,0).r;
    vec3 view;
    if(depth<1.0) {
#ifdef LW_STABLE_DYNAMIC
        int kind=sampleOwner(uv,depth,false);
        view=reconstructProjection(uv,depth,gbufferProjectionInverse,kind!=0);
        if(kind!=0) {
            vec3 n=transpose(mat3(gbufferModelViewInverse))*decodeNormal(texelFetch(colortex1,pixel,0).xy);
            view=stableViewSurfacePosition(view,uv,n,gbufferProjectionInverse);
        }
#else
        view=reconstructViewPosition(depthPixelUv(depthtex0,pixel),depth);
#endif
        distanceToSurface=length(view);
    } else {
#ifdef LW_GEOMETRY_TAAU
        vec2 skyUv=unjitteredUv(uv,true);
#else
        vec2 skyUv=uv;
#endif
        view=(gbufferProjectionInverse*vec4(skyUv*2.0-1.0,1.0,1.0)).xyz;
        distanceToSurface=680.0;
#ifdef DISTANT_HORIZONS
        ivec2 dhPixel=depthPixelAtUv(dhDepthTex0,uv);
        float distantDepth=texelFetch(dhDepthTex0,dhPixel,0).r;
        if(distantDepth<1.0) {
            vec2 distantUv=depthPixelUv(dhDepthTex0,dhPixel);
#ifdef LW_STABLE_DYNAMIC
            int kind=sampleOwner(uv,distantDepth,true);
            view=reconstructProjection(distantUv,distantDepth,dhProjectionInverse,kind!=0);
            if(kind!=0) {
                vec3 n=transpose(mat3(gbufferModelViewInverse))*decodeNormal(texelFetch(colortex1,pixel,0).xy);
                view=stableViewSurfacePosition(view,uv,n,dhProjectionInverse);
            }
#else
            view=reconstructProjection(distantUv,distantDepth,dhProjectionInverse,true);
#endif
            distanceToSurface=length(view);
        }
#endif
    }
    direction=normalize(worldDirection(view));
}
#endif
