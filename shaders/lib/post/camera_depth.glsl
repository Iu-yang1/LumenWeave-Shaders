#ifndef LW_CAMERA_DEPTH
#define LW_CAMERA_DEPTH
#include "/lib/coordinates/raster_grid.glsl"
#ifndef LW_POST_DEPTH0_UNIFORM
#define LW_POST_DEPTH0_UNIFORM
uniform sampler2D depthtex0;
#endif
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform bool firstPersonCamera;
uniform mat4 gbufferProjectionInverse;
#ifdef DISTANT_HORIZONS
#ifndef LW_POST_DH_DEPTH0_UNIFORM
#define LW_POST_DH_DEPTH0_UNIFORM
uniform sampler2D dhDepthTex0;
#endif
uniform mat4 dhProjectionInverse;
#endif
float lwLinearDepth(mat4 inverseProjection,float depth) {
    // Only homogeneous z/w contribute to axial focus depth.
    float ndc=depth*2.0-1.0;
    float z=inverseProjection[2].z*ndc+inverseProjection[3].z;
    float w=inverseProjection[2].w*ndc+inverseProjection[3].w;
    return clamp(-z/max(abs(w),0.00001),0.05,512.0);
}
float lwWorldFocusDepth(vec2 uv) {
    // Focus on actual world geometry, not hand or translucent weather.
    float depth=lwPostDepth(depthtex2,uv);
#ifdef DISTANT_HORIZONS
    if(depth>=1.0) {
        float distant=lwPostDepth(dhDepthTex0,uv);
        if(distant<1.0) return lwLinearDepth(dhProjectionInverse,distant);
    }
#endif
    return depth>=1.0?512.0:lwLinearDepth(gbufferProjectionInverse,depth);
}
float lwDofDepth(vec2 uv) {
    float depth=lwPostDepth(depthtex0,uv);
    // Hand depth is compressed. Only pay for the two extra taps near it.
    if(firstPersonCamera && depth<0.56) {
        float solid=lwPostDepth(depthtex1,uv);
        float withoutHand=lwPostDepth(depthtex2,uv);
        if(solid+0.00001<withoutHand || depth+0.00001<solid) return -1.0;
    }
#ifdef DISTANT_HORIZONS
    if(depth>=1.0) {
        float distant=lwPostDepth(dhDepthTex0,uv);
        if(distant<1.0) return lwLinearDepth(dhProjectionInverse,distant);
    }
#endif
    return depth>=1.0?512.0:lwLinearDepth(gbufferProjectionInverse,depth);
}
#endif
