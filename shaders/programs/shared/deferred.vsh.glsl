#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_viewport.glsl"
out vec2 texCoord;
void main(){
    gl_Position=lwRasterClip(ftransform(),2);
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
}
