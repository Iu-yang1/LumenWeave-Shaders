#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
uniform sampler2D depthtex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
#define LW_REFLECTION_DEPTH depthtex0
#define LW_NATIVE_HIZ
#define LW_REFLECTION_DH_DEPTH dhDepthTex0
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#define LW_REFLECTION_OWNER
#endif
#include "/lib/reflection/trace.glsl"
#ifdef WET_SURFACES
#include "/lib/materials/vanilla.glsl"
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
#include "/lib/materials/lab_surface.glsl"
#endif
#include "/lib/weather/wet_surface.glsl"
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
    vec2 texel=1.0/vec2(lwRasterSize(colortex8));
    vec3 sum=center;float total=1.0;
    const vec2 taps[4]=vec2[4](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1));
    for(int i=0;i<4;++i) {
        vec2 p=uv+taps[i]*texel*radius;
        if(!insideScreen(p)) continue;
        float other=reflectedDepth(p,kind);
        if(other<=0.0 || abs(other-depth)>max(0.25,depth*0.02)) continue;
        float w=0.5;
        sum+=lwRasterTexture(colortex8,p).rgb*w;total+=w;
    }
    return sum/total;
}

float materialReflectionContribution(vec3 viewPosition,vec4 metadata) {
#ifdef ADAPTIVE_SHADING
    float reflectance=max(metadata.r,max(metadata.g,metadata.b));
    float smoothness=1.0-smoothstep(0.18,0.65,metadata.a);
    return (1.0-smoothstep(80.0,144.0,-viewPosition.z))*smoothstep(0.002,0.012,reflectance*smoothness);
#else
    return 1.0;
#endif
}
vec4 traceMaterialCorrectionBudget(ivec2 pixel,vec3 viewPosition,vec3 normal,vec4 geometry,vec4 materialDepth,vec4 metadata,int stepBudget) {
    float roughness=metadata.a;
    float smoothness=1.0-smoothstep(0.18,0.65,roughness);
    if(smoothness<=0.001 || MATERIAL_REFLECTION_STEPS == 0) return vec4(0.0);
#ifdef ADAPTIVE_SHADING
    if(materialReflectionContribution(viewPosition,metadata)<=0.001) return vec4(0.0);
#endif
    mat3 toView=transpose(mat3(gbufferModelViewInverse));
    vec3 eye=normalize(worldDirection(-viewPosition));
    vec3 traceNormal=normal;
#ifdef WET_SURFACES
    vec3 albedo=texelFetch(colortex0,pixel,0).rgb;
    Material material=vanillaMaterial(int(materialDepth.y),albedo);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
    material=labMaterial(material,albedo,materialDepth.z,materialDepth.w);
#endif
    traceNormal=wetRippleNormal(normal,geometry.zw,viewPosition,material);
#endif
    vec3 reflected=reflect(-eye,traceNormal);
    int steps=min(MATERIAL_REFLECTION_STEPS,stepBudget);
#ifdef ADAPTIVE_SHADING
    // Projected footprint of a one-block feature: retain more taps at high
    // display resolution / narrow FOV where the same distance is more visible.
    float pixelsPerBlock=0.5*abs(gbufferProjection[1][1])
        *float(lwRasterSize(depthtex0).y)/max(-viewPosition.z,0.1);
#if SSR_FOOTPRINT > 0
    // Approximate screen-space footprint of a one-block material patch.
    // Sharp mirrors retain the selected ceiling; rough lobes and small
    // projected patches spend fewer taps. Avoid crossing the short-ray
    // range switch (<=8) unless the caller explicitly asked for that budget.
    float lobe=smoothstep(0.20,0.55,roughness);
    float small=1.0-smoothstep(8.0,40.0,pixelsPerBlock);
    float reflectance=max(metadata.r,max(metadata.g,metadata.b))*smoothness;
    float weak=1.0-smoothstep(0.008,0.05,reflectance);
    float reduction=lobe*max(small,weak)* (SSR_FOOTPRINT==2?0.60:0.42);
    int reduced=max(min(9,steps),int(ceil(float(steps)*(1.0-reduction))));
    steps=min(steps,reduced);
#else
    if((-viewPosition.z>36.0 && pixelsPerBlock<14.0) || roughness>0.38)
        steps=min(steps,max(9,steps/2));
#endif
#endif
    vec2 hitUv;float travel;int hitKind;
    vec4 hit=traceScreenReflection(viewPosition+toView*traceNormal*0.07,toView*reflected,steps,hitUv,travel,hitKind);
    vec3 correction=vec3(0.0);
    if(hit.a>0.0) {
        vec3 filtered=filterReflection(hit.rgb,hitUv,travel,hitKind,roughness);
        // Replace exact environment contribution; indoor rays are independent of sky access.
        vec3 fallback=texelFetch(colortex13,pixel,0).rgb;
        correction=(filtered*metadata.rgb-fallback)*(hit.a*smoothness);
    }
    return vec4(correction,hit.a);
}

vec4 traceMaterialCorrection(ivec2 pixel,vec3 viewPosition,vec3 normal,vec4 geometry,vec4 materialDepth,vec4 metadata){return traceMaterialCorrectionBudget(pixel,viewPosition,normal,geometry,materialDepth,metadata,MATERIAL_REFLECTION_STEPS);}
