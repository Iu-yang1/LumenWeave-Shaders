// Reconstruct the shared half-resolution AO only on matching geometry.
uniform sampler2D colortex3;
float spatialGroundTruthOcclusion(vec2 uv,vec3 position,vec3 normal,vec3 normalView) {
    float depth=-position.z;
    if(depth>=52.0 || AO_STRENGTH==0.0) return 1.0;
    if(depth<4.0) return groundTruthOcclusion(uv,position,normalView);
    ivec2 size=textureSize(colortex3,0);
    ivec2 fullSize=textureSize(colortex1,0);
    vec2 coordinate=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(coordinate));
    vec2 fraction=fract(coordinate);
    float tolerance=max(0.12,depth*0.035);
    float total=0.0,coverage=0.0;
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=base+ivec2(x,y);
        if(any(lessThan(p,ivec2(0))) || any(greaterThanEqual(p,size))) continue;
        vec2 sampleValue=texelFetch(colortex3,p,0).rg;
        float delta=abs(sampleValue.y-depth);
        if(sampleValue.y<=0.0 || delta>=tolerance) continue;
        ivec2 donor=clamp(ivec2((vec2(p)+0.5)*vec2(fullSize)/vec2(size)),ivec2(0),fullSize-1);
        if(dot(normal,decodeNormal(texelFetch(colortex1,donor,0).xy))<0.85) continue;
        vec2 w=mix(1.0-fraction,fraction,vec2(x,y));
        float weight=w.x*w.y*(1.0-smoothstep(0.35,1.0,delta/tolerance));
        total+=sampleValue.x*weight;
        coverage+=weight;
    }
    if(coverage<=0.003) return groundTruthOcclusion(uv,position,normalView);
    float filtered=total/coverage;
    float confidence=smoothstep(0.003,0.035,coverage)*smoothstep(4.0,6.0,depth);
    if(confidence>=0.999) return filtered;
    return mix(groundTruthOcclusion(uv,position,normalView),filtered,confidence);
}
