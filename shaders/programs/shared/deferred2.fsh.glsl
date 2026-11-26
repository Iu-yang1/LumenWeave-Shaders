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
#include "/lib/reflection/material_trace.glsl"
#ifdef LW_TAA_ACTIVE
#include "/lib/reflection/material_history.glsl"
#endif
#ifdef LW_SSR_HALF
uniform sampler2D colortex9;
// The prepass owns the transient GI attachment only after deferred1 consumed it.
bool reconstructRoughReflection(vec2 uv,vec3 viewPosition,vec3 normal,vec4 metadata,out vec4 result) {
    if(metadata.a<0.28) return false;
    ivec2 size=textureSize(colortex9,0),fullSize=textureSize(depthtex0,0);
    vec2 coord=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(coord));vec2 f=fract(coord);
    vec4 total=vec4(0.0);float weightSum=0.0;
    for(int y=0;y<2;++y)for(int x=0;x<2;++x) {
        ivec2 p=base+ivec2(x,y);
        if(any(lessThan(p,ivec2(0)))||any(greaterThanEqual(p,size))) continue;
        vec2 w=mix(1.0-f,f,vec2(x,y));
        float weight=w.x*w.y;
        if(weight<=0.00001) continue;
        ivec2 donor=clamp(ivec2((vec2(p)+0.5)*vec2(fullSize)/vec2(size)),ivec2(0),fullSize-1);
        vec4 m=texelFetch(colortex12,donor,0);
        if(m.a<0.28 || abs(m.a-metadata.a)>0.08 || length(m.rgb-metadata.rgb)>0.06) continue;
        float depth=texelFetch(depthtex0,donor,0).r;
        if(depth>=1.0 || abs(depth-texelFetch(colortex2,donor,0).r)>0.00000012) continue;
        float distance=-reconstructViewPosition(depthPixelUv(depthtex0,donor),depth).z;
        float tolerance=max(0.12,-viewPosition.z*0.025);
        if(abs(distance+viewPosition.z)>=tolerance) continue;
        if(dot(normal,decodeNormal(texelFetch(colortex1,donor,0).xy))<0.94) continue;
        weight*=1.0-smoothstep(tolerance*0.35,tolerance,abs(distance+viewPosition.z));
        total+=texelFetch(colortex9,p,0)*weight;weightSum+=weight;
    }
    if(weightSum<0.20) return false;
    result=total/weightSum;
    return true;
}
#endif

void main() {
    ivec2 pixel=ivec2(gl_FragCoord.xy);
    sceneOutput=texelFetch(colortex0,pixel,0);
    opaqueOutput=texelFetch(colortex8,pixel,0);
#ifdef LW_TAA_ACTIVE
    reflectionHistory=vec4(0.0);
    reflectionGeometry=vec4(0.0);
#endif
    vec4 metadata=texelFetch(colortex12,pixel,0);
    float reflectance=max(metadata.r,max(metadata.g,metadata.b));
    if(reflectance<=0.001) return;
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
    float contribution=materialReflectionContribution(viewPosition,metadata);
    if(contribution<=0.001 || MATERIAL_REFLECTION_STEPS==0) return;
    vec4 sampleResult;
#ifdef LW_SSR_HALF
    if(!reconstructRoughReflection(texCoord,viewPosition,normal,metadata,sampleResult))
#endif
        sampleResult=traceMaterialCorrection(pixel,viewPosition,normal,geometry,materialDepth,metadata);
    vec3 correction=sampleResult.rgb;
#ifdef LW_TAA_ACTIVE
    correction=temporalReflectionCorrection(correction,sampleResult.a,viewPosition,normal,texCoord);
    reflectionHistory=vec4(correction,-viewPosition.z);
    reflectionGeometry=vec4(geometry.xy,vec2(textureSize(depthtex0,0)));
#endif
    opaqueOutput.rgb=max(opaqueOutput.rgb+correction*contribution,vec3(0.0));
    sceneOutput.rgb=applySceneFog(opaqueOutput.rgb,viewPosition);
}
#else
/* RENDERTARGETS: 0 */
void main(){ sceneOutput=texture(colortex0,texCoord); }
#endif
