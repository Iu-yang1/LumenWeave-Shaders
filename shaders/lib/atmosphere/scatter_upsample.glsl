#ifdef LW_SCATTER_UPSAMPLE_ACTIVE
uniform sampler2D colortex11;
vec3 upsampleLocalScatter(vec2 uv,vec3 direction,float distanceToSurface) {
    ivec2 size=textureSize(colortex11,0);
    vec2 coordinate=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(coordinate));
    vec2 f=fract(coordinate);
    float depth=min(distanceToSurface,float(LW_GRID_SIZE)*0.5-1.0);
    float tolerance=max(0.20,depth*0.025);
    vec3 total=vec3(0.0);
    float weightSum=0.0;
    float spatialSum=0.0;
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=clamp(base+ivec2(x,y),ivec2(0),size-1);
        vec4 sampleValue=texelFetch(colortex11,p,0);
        vec2 w=mix(1.0-f,f,vec2(x,y));
        float spatial=w.x*w.y;
        float difference=abs(sampleValue.a-depth);
        if(difference>tolerance) continue;
        float weight=spatial*(1.0-smoothstep(tolerance*0.35,tolerance,difference));
        total+=sampleValue.rgb*weight;
        weightSum+=weight;
        spatialSum+=spatial;
    }
    // Thin objects and depth discontinuities use the exact full-resolution ray.
    if(spatialSum<0.85 || weightSum<0.05) return integrateLocalScatter(direction,distanceToSurface);
    return total/weightSum;
}
#endif
