#include "/lib/temporal/reproject.glsl"
uniform sampler2D colortex14;
uniform sampler2D colortex15;

vec3 temporalReflectionCorrection(vec3 current,float confidence,vec3 position,vec3 normal,vec2 uv) {
    vec2 previousUv;float expectedDepth;
#ifdef LW_GEOMETRY_TAAU
    if(!reprojectTerrain(position,previousUv,expectedDepth)) return current;
#else
    if(!reprojectStableTerrain(position,previousUv,expectedDepth,gbufferPreviousProjection)) return current;
#endif
    ivec2 size=lwRasterSize(colortex14);
    vec2 p=previousUv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(p));
    vec2 f=fract(p);vec3 accumulated=vec3(0.0);float total=0.0;
    for(int y=0;y<2;++y)for(int x=0;x<2;++x) {
        ivec2 pixel=base+ivec2(x,y);
        if(any(lessThan(pixel,ivec2(0))) || any(greaterThanEqual(pixel,size))) continue;
        vec4 sampleColor=texelFetch(colortex14,pixel,0);
        vec4 metadata=texelFetch(colortex15,pixel,0);
        if(!matchesHistoryDepth(sampleColor.a,expectedDepth) ||
            any(greaterThan(abs(metadata.zw-vec2(size)),vec2(1.0))) ||
            dot(decodeNormal(metadata.xy),normal)<0.92) continue;
        vec2 weights=mix(1.0-f,f,vec2(x,y));float w=weights.x*weights.y;
        accumulated+=sampleColor.rgb*w;total+=w;
    }
    if(total<0.25) return current;
    vec3 history=accumulated/total;
    vec3 envelope=max(abs(current)*0.75,vec3(0.035));
    history=clamp(history,current-envelope,current+envelope);
    float motion=length((previousUv-uv)*vec2(size));
    float weight=mix(0.35,0.80,confidence)*total*(1.0-smoothstep(2.0,20.0,motion));
    return mix(current,history,weight);
}
