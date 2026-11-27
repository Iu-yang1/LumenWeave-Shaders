#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_viewport.glsl"
#if FRAME_LIGHTING_REUSE == 1
#define LW_FRAME_LIGHTING_VERTEX
#include "/lib/lighting/overworld.glsl"
#endif
out vec2 texCoord;
void main(){
#if FRAME_LIGHTING_REUSE == 1
    lwFrameSun=sunDirection();
    lwFrameDirect=celestialIrradiance(lwFrameSun);
    lwFrameWeights=vec2(daylight(lwFrameSun),celestialVisibility(lwFrameSun));
#endif
    gl_Position=lwRasterClip(ftransform(),1);
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
}
