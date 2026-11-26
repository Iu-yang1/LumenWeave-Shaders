#ifndef LW_MOTION_STATE
#define LW_MOTION_STATE
// Exact same transform predicate as composite2.vsh; no motion tolerance or
// changes to jitter, projection, blur samples, or camera state are introduced.
#ifndef LW_MOTION_TRANSFORMS_DECLARED
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
#ifndef LW_MOTION_PROJECTION_DECLARED
uniform mat4 gbufferProjection;
#endif
uniform mat4 gbufferPreviousProjection;
uniform ivec3 cameraPositionInt;
uniform ivec3 previousCameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 previousCameraPositionFract;
#endif
#ifdef DISTANT_HORIZONS
uniform mat4 dhProjection;
uniform mat4 dhPreviousProjection;
#endif
bool lwMotionIsIdentity(){
    return gbufferModelView==gbufferPreviousModelView &&
        gbufferProjection==gbufferPreviousProjection &&
        all(equal(cameraPositionInt,previousCameraPositionInt)) &&
        all(equal(cameraPositionFract,previousCameraPositionFract))
#ifdef DISTANT_HORIZONS
        && dhProjection==dhPreviousProjection
#endif
        ;
}
#endif
