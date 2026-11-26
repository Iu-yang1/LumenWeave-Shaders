in vec2 texCoord;
in vec4 vertexColor;
in vec3 normalWorld;
in vec2 lightLevels;
#ifdef LW_TEXTURED
uniform sampler2D gtexture;
#endif
/* RENDERTARGETS: 0,1 */
layout(location=0) out vec4 color;
layout(location=1) out vec4 normal;
const int colortex0Format=RGBA16F;
const int colortex1Format=RGBA16F;
void main(){
    vec4 base=vertexColor;
#ifdef LW_TEXTURED
    base*=texture(gtexture,texCoord);
#endif
    if(base.a<0.1) discard;
#ifdef LW_LIT
    base.rgb*=0.15+0.85*max(lightLevels.x,lightLevels.y);
#endif
    color=base;
    vec3 n=normalWorld*inversesqrt(max(dot(normalWorld,normalWorld),1e-6));
    normal=vec4(n,1.0);
}
