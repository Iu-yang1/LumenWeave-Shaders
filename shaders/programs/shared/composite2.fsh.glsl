#version 330 compatibility

#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_grid.glsl"

#ifdef LW_TAA_HISTORY_ONLY
uniform sampler2D colortex4;
#define LW_MOTION_SOURCE colortex4
#else
uniform sampler2D colortex0;
#define LW_MOTION_SOURCE colortex0
#endif
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;
/* RENDERTARGETS: 0 */

#ifdef MOTION_BLUR
flat in int lwMotionActive;
#include "/lib/post/motion_blur.glsl"
#endif

void main() {
    outputColor = texture(LW_MOTION_SOURCE, texCoord);
#ifdef LW_TAA_HISTORY_ONLY
    outputColor.a=1.0;
#endif
#ifdef MOTION_BLUR
    outputColor.rgb=lwMotionBlur(LW_MOTION_SOURCE,texCoord,outputColor.rgb,lwMotionActive!=0);
#endif
}
