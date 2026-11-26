#version 330 compatibility
#include "/lib/quality.glsl"
out vec2 texCoord;
#ifdef SOLAR_GLARE
flat out vec4 lwSolar;
#include "/lib/post/solar_visibility.glsl"
#ifdef LW_TAA_DIRECT
uniform sampler2D colortex4;
#define LW_GLARE_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_GLARE_SOURCE colortex0
#endif
#ifdef LW_EXPOSURE_METER
uniform sampler2D lwExposureSampler;
#endif
#endif
void main(){
    gl_Position=ftransform();
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
#ifdef SOLAR_GLARE
    lwSolar=solarVisibility(LW_GLARE_SOURCE);
#ifdef LW_EXPOSURE_METER
    // Smooth appearance without permitting ghost glare through a new occluder.
    lwSolar.z=min(lwSolar.z,texelFetch(lwExposureSampler,ivec2(0),0).b);
#endif
#endif
}
