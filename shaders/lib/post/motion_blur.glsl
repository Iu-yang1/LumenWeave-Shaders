#ifndef LW_MOTION_BLUR_LIBRARY
#define LW_MOTION_BLUR_LIBRARY
#include "/lib/post/camera_depth.glsl"
#include "/lib/post/motion_state.glsl"
#include "/lib/temporal/jitter.glsl"
uniform mat4 gbufferModelViewInverse;
vec3 lwMotionBlur(sampler2D source,vec2 texCoord,vec3 center,bool moving) {
    // Vertex-stage uniform check avoids per-pixel reprojection while still.
    if(!moving) return center;
    vec3 cameraDelta=vec3(cameraPositionInt-previousCameraPositionInt)+cameraPositionFract-previousCameraPositionFract;
    if (dot(cameraDelta, cameraDelta) > 16.0) {
        return center;
    }
    float depth = lwPostDepth(depthtex0,texCoord);
    if (depth < 0.55) {
        return center;
    }
    bool distant = false;
    mat4 projectionInverse = gbufferProjectionInverse;
    mat4 previousProjection = gbufferPreviousProjection;
#ifdef DISTANT_HORIZONS
    if (depth >= 1.0) {
        depth = lwPostDepth(dhDepthTex0,texCoord);
        distant = depth < 1.0;
        projectionInverse = dhProjectionInverse;
        previousProjection = dhPreviousProjection;
    }
#endif
    vec2 currentUv = texCoord;
#if defined(LW_TAA_ACTIVE) && !defined(LW_GEOMETRY_TAAU)
    currentUv -= jitterOffset(frameCounter);
#endif
    vec4 position = projectionInverse * vec4(vec3(currentUv, min(depth, 0.99999)) * 2.0 - 1.0, 1.0);
    vec3 view = position.xyz / position.w;
    vec3 relative = (gbufferModelViewInverse * vec4(view, 1.0)).xyz;
    vec4 previousView = depth >= 1.0
        ? gbufferPreviousModelView * vec4(mat3(gbufferModelViewInverse) * view, 0.0)
        : gbufferPreviousModelView * vec4(relative + cameraDelta, 1.0);
    vec4 previousClip = previousProjection * previousView;
    if (previousClip.w <= 0.0) {
        return center;
    }
    vec2 velocity = (currentUv - (previousClip.xy / previousClip.w * 0.5 + 0.5)) * MOTION_BLUR_STRENGTH;
    vec2 resolution = vec2(textureSize(source, 0));
    float pixels = length(velocity * resolution);
    if (pixels < 0.35) {
        return center;
    }
    velocity *= min(1.0, 24.0 / pixels);
    // Subpixel/short streaks do not need a fixed eight-tap quadrature.
    // The configured count remains the ceiling for larger motion.
    int tapCount=min(MOTION_BLUR_SAMPLES,max(2,int(ceil(min(pixels,24.0)*0.75))+1));
    float inverseTapCount=1.0/float(tapCount);
    float depthTolerance=max(0.5,-view.z*0.035);
    vec4 zRow=vec4(projectionInverse[0].z,projectionInverse[1].z,projectionInverse[2].z,projectionInverse[3].z);
    vec4 wRow=vec4(projectionInverse[0].w,projectionInverse[1].w,projectionInverse[2].w,projectionInverse[3].w);
    vec4 residualRow=zRow-view.z*wRow;
    vec3 accumulated = center;
    float total = 1.0;
    for (int tap = 0; tap < MOTION_BLUR_SAMPLES; ++tap) {
        if(tap>=tapCount) break;
        float offset = (float(tap) + 0.5) * inverseTapCount - 0.5;
        vec2 uv = texCoord + velocity * offset;
        if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
            continue;
        }
        float adjacentDepth = lwPostDepth(depthtex0,uv);
#ifdef DISTANT_HORIZONS
        if (distant) {
            if(adjacentDepth<1.0) continue;
            adjacentDepth = lwPostDepth(dhDepthTex0,uv);
        }
#endif
        if ((adjacentDepth >= 1.0) != (depth >= 1.0)) {
            continue;
        }
        if (depth < 1.0) {
            vec4 ndc=vec4(vec3(uv,adjacentDepth)*2.0-1.0,1.0);
            // Exact homogeneous depth inequality, avoiding a division per tap.
            if(abs(dot(residualRow,ndc))>depthTolerance*abs(dot(wRow,ndc))) {
                continue;
            }
        }
        float weight = 1.0 - abs(offset);
        accumulated += textureLod(source, uv, 0.0).rgb * weight;
        total += weight;
    }
    return accumulated / total;
}
#endif
