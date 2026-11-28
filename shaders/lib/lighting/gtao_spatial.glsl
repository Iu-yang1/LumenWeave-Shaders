// Reconstruct the shared half-resolution AO only on matching geometry.
uniform sampler2D colortex3;
#if AO_NEAR_RECONSTRUCTION == 1
#include "/lib/lighting/donor_plane.glsl"
#endif
float spatialGroundTruthOcclusion(vec2 uv,vec3 position,vec3 normal,vec3 normalView) {
    float depth=-position.z;
    if(depth>=52.0 || AO_STRENGTH==0.0) return 1.0;
#if AO_NEAR_RECONSTRUCTION == 1
    if(depth<0.35) return groundTruthOcclusion(uv,position,normalView);
    bool nearField=depth<6.0;
    float minimumAo=1.0,maximumAo=0.0;
    int accepted=0;
#else
    if(depth<4.0) return groundTruthOcclusion(uv,position,normalView);
#endif
    ivec2 size=lwRasterSize(colortex3);
    ivec2 fullSize=lwRasterSize(colortex1);
    vec2 coordinate=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(coordinate));
    vec2 fraction=fract(coordinate);
    float tolerance=max(0.12,depth*0.035);
    float total=0.0,coverage=0.0;
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=base+ivec2(x,y);
        if(any(lessThan(p,ivec2(0))) || any(greaterThanEqual(p,size))) continue;
        vec2 w=mix(1.0-fraction,fraction,vec2(x,y));
        float spatial=w.x*w.y;
        if(spatial<=0.00001) continue;
        vec2 sampleValue=texelFetch(colortex3,p,0).rg;
        float donorDepth=depth;
#if AO_NEAR_RECONSTRUCTION == 1
        ivec2 donor=clamp(ivec2((vec2(p)+0.5)*vec2(fullSize)/vec2(size)),ivec2(0),fullSize-1);
        if(nearField && !donorPlaneDepth(position,normalView,(vec2(donor)+0.5)/vec2(fullSize),donorDepth)) continue;
#endif
        float delta=abs(sampleValue.y-donorDepth);
        if(sampleValue.y<=0.0 || delta>=tolerance) continue;
#if AO_NEAR_RECONSTRUCTION == 0
        ivec2 donor=clamp(ivec2((vec2(p)+0.5)*vec2(fullSize)/vec2(size)),ivec2(0),fullSize-1);
#endif
        float alignment=dot(normal,decodeNormal(texelFetch(colortex1,donor,0).xy));
#if AO_NEAR_RECONSTRUCTION == 1
        if(nearField && alignment<0.98) continue;
#endif
        if(alignment<0.85) continue;
        float weight=spatial*(1.0-smoothstep(0.35,1.0,delta/tolerance));
        total+=sampleValue.x*weight;
        coverage+=weight;
#if AO_NEAR_RECONSTRUCTION == 1
        minimumAo=min(minimumAo,sampleValue.x);
        maximumAo=max(maximumAo,sampleValue.x);
        ++accepted;
#endif
    }
    if(coverage<=0.003) return groundTruthOcclusion(uv,position,normalView);
    float filtered=total/coverage;
#if AO_NEAR_RECONSTRUCTION == 1
    if(nearField) {
        if(accepted<2 || coverage<0.72 || maximumAo-minimumAo>0.08)
            return groundTruthOcclusion(uv,position,normalView);
        float confidence=smoothstep(0.35,0.75,depth);
        if(confidence>=0.999) return filtered;
        return mix(groundTruthOcclusion(uv,position,normalView),filtered,confidence);
    }
#endif
#if APPROX_REUSE == 1
    // Geometry ownership already passed. Only genuinely weak donors or
    // the near transition need a second expensive horizon integration.
    float confidence=smoothstep(0.003,0.012,coverage)*smoothstep(4.0,6.0,depth);
#else
    float confidence=smoothstep(0.003,0.035,coverage)*smoothstep(4.0,6.0,depth);
#endif
    if(confidence>=0.999) return filtered;
    return mix(groundTruthOcclusion(uv,position,normalView),filtered,confidence);
}
