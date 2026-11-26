// Shared lens footprint: idle softness and radial peripheral optics are
// composed in one bounded four-donor filter, after ordinary scene DoF.
#ifdef LW_IDLE_FOCUS
#ifndef LW_CAMERA_STATE_SAMPLER
#define LW_CAMERA_STATE_SAMPLER
uniform sampler2D lwExposureSampler;
#endif
#endif
vec3 lwLensOptics(sampler2D source,vec2 uv,vec3 scene){
    vec2 size=vec2(textureSize(source,0));
    vec2 texel=1.0/size;
    float scale=size.y/1080.0;
    float idle=0.0,edge=0.0;
#ifdef LW_IDLE_FOCUS
    idle=texelFetch(lwExposureSampler,ivec2(2,0),0).y*DOF_IDLE_STRENGTH;
#endif
#if PERIPHERAL_OPTICS == 1
    edge=smoothstep(0.55,1.25,length((uv-0.5)*2.0))*PERIPHERAL_STRENGTH;
#endif
    if(max(idle,edge)<0.005) return scene;
    vec2 radial=(uv-0.5)*size;
    radial=length(radial)>0.001?normalize(radial):vec2(1.0,0.0);
    vec2 tangent=vec2(-radial.y,radial.x);
    float radius=(6.0*idle+2.0*edge)*scale;
    vec2 delta=radial*texel*radius;
    vec2 crossDelta=tangent*texel*radius;
    vec2 lo=texel*0.5,hi=1.0-lo;
    vec3 a=texture(source,clamp(uv-delta,lo,hi)).rgb;
    vec3 b=texture(source,clamp(uv+delta,lo,hi)).rgb;
    vec3 c=texture(source,clamp(uv-crossDelta,lo,hi)).rgb;
    vec3 d=texture(source,clamp(uv+crossDelta,lo,hi)).rgb;
    vec3 soft=(a+b+c+d)*0.25;
    // Use the radial donors for subtle wavelength separation; do not darken.
    // Opposed signed differences preserve a constant-color image.
    soft+=vec3(b.r-a.r,0.0,a.b-b.b)*(0.18*edge);
    float amount=clamp(idle*1.2+edge*0.6,0.0,0.85);
    return mix(scene,max(soft,vec3(0.0)),amount);
}
