#version 330 compatibility
#include "/lib/quality.glsl"
out vec2 texCoord;
#ifdef MOTION_BLUR
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;
uniform ivec3 cameraPositionInt;
uniform ivec3 previousCameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 previousCameraPositionFract;
#ifdef DISTANT_HORIZONS
uniform mat4 dhProjection;
uniform mat4 dhPreviousProjection;
#endif
flat out int lwMotionActive;
#endif
void main(){
    gl_Position=ftransform();
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
#ifdef MOTION_BLUR
    // Same value at every fullscreen vertex; exact unchanged transforms only.
    lwMotionActive=(gbufferModelView!=gbufferPreviousModelView ||
        gbufferProjection!=gbufferPreviousProjection ||
        any(notEqual(cameraPositionInt,previousCameraPositionInt)) ||
        any(notEqual(cameraPositionFract,previousCameraPositionFract))
#ifdef DISTANT_HORIZONS
        || dhProjection!=dhPreviousProjection
#endif
        )?1:0;
#ifdef LW_STATIC_HDR_REUSE
    // No color writes or pixel invocations when the motion filter is identity.
    // Subsequent consumers use the current TAA resolve instead of colortex0.
    if(lwMotionActive==0) gl_Position=vec4(2.0,2.0,2.0,1.0);
#endif
#endif
}
