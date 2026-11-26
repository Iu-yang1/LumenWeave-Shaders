#version 330 compatibility
#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 sceneOutput;

#ifdef LW_MATERIAL_SSR_ACTIVE
layout(location = 1) out vec4 opaqueOutput;
#ifdef LW_TAA_ACTIVE
/* RENDERTARGETS: 0,8,14,15 */
layout(location = 2) out vec4 reflectionHistory;
layout(location = 3) out vec4 reflectionGeometry;
/*
const int colortex14Format = RGBA16F;
const int colortex15Format = RGBA16F;
const bool colortex14Clear = false;
const bool colortex15Clear = false;
const vec4 colortex14ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex15ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#else
/* RENDERTARGETS: 0,8 */
#endif

#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/fog.glsl"
#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
uniform sampler2D depthtex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
#define LW_REFLECTION_DEPTH depthtex0
#define LW_REFLECTION_DH_DEPTH dhDepthTex0
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#define LW_REFLECTION_OWNER
#endif
#include "/lib/reflection/trace.glsl"
#ifdef LW_TAA_ACTIVE
#include "/lib/reflection/material_history.glsl"
#endif

float reflectedDepth(vec2 uv,int kind) {
    if(kind==1) {
        ivec2 p=depthPixelAtUv(depthtex0,uv);
        float d=texelFetch(depthtex0,p,0).r;
        if(d>=1.0) return -1.0;
        return -reflectionNativePosition(depthPixelUv(depthtex0,p),d,uv).z;
    }
#ifdef DISTANT_HORIZONS
    if(kind==2 && depthAtUv(depthtex0,uv)>=1.0) {
        ivec2 p=depthPixelAtUv(dhDepthTex0,uv);
        float d=texelFetch(dhDepthTex0,p,0).r;
        if(d>=1.0) return -1.0;
        return -reconstructProjection(depthPixelUv(dhDepthTex0,p),d,dhProjectionInverse,true).z;
    }
#endif
    return -1.0;
}

vec3 filterReflection(vec3 center,vec2 uv,float travel,int kind,float roughness) {
    float radius=clamp(roughness*roughness*travel*0.75,0.0,6.0);
    if(radius<0.65) return center;
    float depth=reflectedDepth(uv,kind);
    if(depth<=0.0) return center;
    vec2 texel=1.0/vec2(textureSize(colortex8,0));
    vec3 sum=center;float total=1.0;
    const vec2 taps[4]=vec2[4](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1));
    for(int i=0;i<4;++i) {
        vec2 p=uv+taps[i]*texel*radius;
        if(!insideScreen(p)) continue;
        float other=reflectedDepth(p,kind);
        if(other<=0.0 || abs(other-depth)>max(0.25,depth*0.02)) continue;
        float w=0.5;
        sum+=texture(colortex8,p).rgb*w;total+=w;
    }
    return sum/total;
}

void main() {
    ivec2 pixel=ivec2(gl_FragCoord.xy);
    sceneOutput=texelFetch(colortex0,pixel,0);
    opaqueOutput=texelFetch(colortex8,pixel,0);
#ifdef LW_TAA_ACTIVE
    reflectionHistory=vec4(0.0);
    reflectionGeometry=vec4(0.0);
#endif
    vec4 metadata=texelFetch(colortex12,pixel,0);
    vec4 fallback=texelFetch(colortex13,pixel,0);
    if(fallback.a<=0.0 || max(metadata.r,max(metadata.g,metadata.b))<=0.001) return;
    float depth=texelFetch(depthtex0,pixel,0).r;
    vec4 materialDepth=texelFetch(colortex2,pixel,0);
    if(depth>=1.0 || abs(depth-materialDepth.x)>0.00000012) return;
    vec4 geometry=texelFetch(colortex1,pixel,0);
    vec3 normal=decodeNormal(geometry.xy);
    vec3 viewPosition=reconstructViewPosition(texCoord,depth);
    mat3 toView=transpose(mat3(gbufferModelViewInverse));
#ifdef LW_STABLE_DYNAMIC
    viewPosition=stableViewSurfacePosition(viewPosition,texCoord,toView*normal,gbufferProjectionInverse);
#endif
    vec3 eye=normalize(worldDirection(-viewPosition));
    vec3 reflected=reflect(-eye,normal);
    float roughness=metadata.a;
    float smoothness=1.0-smoothstep(0.18,0.65,roughness);
    if(smoothness<=0.001) return;
    vec2 hitUv;float travel;int hitKind;
    vec4 hit=traceScreenReflection(viewPosition+toView*normal*0.07,toView*reflected,16,hitUv,travel,hitKind);
    vec3 correction=vec3(0.0);
    if(hit.a>0.0) {
        vec3 filtered=filterReflection(hit.rgb,hitUv,travel,hitKind,roughness);
        // Replace exact environment contribution; indoor rays are independent of sky access.
        correction=(filtered*metadata.rgb-fallback.rgb)*(hit.a*smoothness);
    }
#ifdef LW_TAA_ACTIVE
    correction=temporalReflectionCorrection(correction,hit.a,viewPosition,normal,texCoord);
    reflectionHistory=vec4(correction,-viewPosition.z);
    reflectionGeometry=vec4(geometry.xy,vec2(textureSize(depthtex0,0)));
#endif
    opaqueOutput.rgb=max(opaqueOutput.rgb+correction,vec3(0.0));
    sceneOutput.rgb=applySceneFog(opaqueOutput.rgb,viewPosition);
}
#else
/* RENDERTARGETS: 0 */
void main(){ sceneOutput=texture(colortex0,texCoord); }
#endif
