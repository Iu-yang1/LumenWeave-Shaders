#include "/lib/grid.glsl"
uniform mat4 gbufferModelViewInverse;
out vec2 texCoord;
out vec4 vertexColor;
out vec3 normalWorld;
out vec2 lightLevels;
void main(){
    gl_Position=scaledClip(gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex);
    texCoord=(gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    vertexColor=gl_Color;
    normalWorld=mat3(gbufferModelViewInverse)*gl_NormalMatrix*gl_Normal;
    lightLevels=clamp(((gl_TextureMatrix[1]*gl_MultiTexCoord1).xy*16.0-0.5)/15.0,0.0,1.0);
}
