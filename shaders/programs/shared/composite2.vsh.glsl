#version 330 compatibility
#include "/lib/quality.glsl"
out vec2 texCoord;
#ifdef MOTION_BLUR
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
flat out int lwMotionActive;
#endif
void main(){
    gl_Position=ftransform();
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
#ifdef MOTION_BLUR
    // Same value at every fullscreen vertex; exact unchanged transforms only.
    lwMotionActive=(gbufferModelView!=gbufferPreviousModelView ||
        gbufferProjection!=gbufferPreviousProjection ||
        any(notEqual(cameraPosition,previousCameraPosition)))?1:0;
#endif
}
