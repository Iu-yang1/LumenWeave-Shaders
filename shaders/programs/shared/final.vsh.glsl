#version 330 compatibility
#include "/lib/quality.glsl"
out vec2 texCoord;
#ifdef LW_STATIC_HDR_REUSE
flat out int lwPostHistory;
#endif
#ifdef SOLAR_GLARE
flat out vec4 lwSolar;
#include "/lib/post/solar_visibility.glsl"
#define LW_MOTION_PROJECTION_DECLARED
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_GLARE_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_GLARE_SOURCE colortex0
#ifdef LW_STATIC_HDR_REUSE
uniform sampler2D colortex4;
#endif
#endif
#ifdef LW_EXPOSURE_METER
uniform sampler2D lwExposureSampler;
#endif
#endif
#ifdef LW_STATIC_HDR_REUSE
#include "/lib/post/motion_state.glsl"
#endif
void main(){
    gl_Position=ftransform();
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
#ifdef LW_STATIC_HDR_REUSE
    lwPostHistory=lwMotionIsIdentity()?1:0;
#endif
#ifdef SOLAR_GLARE
#ifdef LW_STATIC_HDR_REUSE
    lwSolar=lwPostHistory!=0?solarVisibility(colortex4):solarVisibility(LW_GLARE_SOURCE);
#else
    lwSolar=solarVisibility(LW_GLARE_SOURCE);
#endif
#ifdef LW_EXPOSURE_METER
    // Smooth appearance without permitting ghost glare through a new occluder.
    lwSolar.z=min(lwSolar.z,texelFetch(lwExposureSampler,ivec2(0),0).b);
#endif
#endif
}
