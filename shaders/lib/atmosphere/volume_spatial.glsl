#ifdef LW_SCENE_TAAU
#include "/lib/temporal/scene_grid.glsl"
#endif
// Reconstruct the affine celestial volume transfer, not already-lit scene RGB.
vec4 celestialVolumeTransfer(vec3 direction,float distanceToSurface) {
    vec3 sun=sunDirection();
    vec3 origin=vec3(cameraPositionInt)+cameraPositionFract;
    vec4 transfer=cloudVolumeTransfer(origin,direction,sun,distanceToSurface);
    transfer.rgb+=applyLightShafts(vec3(0.0),origin,direction,sun,distanceToSurface);
    return transfer;
}
#ifdef LW_VOLUME_SPATIAL_READER
uniform sampler2D colortex9;
#ifdef LW_AO_SPATIAL
uniform sampler2D colortex3;
#endif
vec4 upsampleCelestialVolume(vec2 uv,vec3 direction,float distanceToSurface) {
    ivec2 size=lwRasterSize(colortex9);
#ifdef LW_SCENE_TAAU
    size=lwSceneRenderSize(size);
#endif
    vec2 coordinate=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(coordinate));
    vec2 f=fract(coordinate);
    // Compare actual ray distance including DH. Keep occlusion at geometry
    // boundaries and a continuous exact fallback for uncovered pixels.
    float tolerance=max(0.45,distanceToSurface*0.045);
    vec4 total=vec4(0.0);
    float coverage=0.0;
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        ivec2 p=clamp(base+ivec2(x,y),ivec2(0),size-1);
#ifdef LW_AO_SPATIAL
        float donorDistance=texelFetch(colortex3,p,0).r;
#else
        vec2 donorUv=(vec2(p)+0.5)/vec2(size);
        vec3 donorDirection;
        float donorDistance;
        volumeRay(donorUv,donorDirection,donorDistance);
#endif
        float difference=abs(donorDistance-distanceToSurface);
        if(difference>=tolerance) continue;
        vec2 w=mix(1.0-f,f,vec2(x,y));
        float weight=w.x*w.y*(1.0-smoothstep(tolerance*0.35,tolerance,difference));
        total+=texelFetch(colortex9,p,0)*weight;
        coverage+=weight;
    }
    if(coverage<=0.003) return celestialVolumeTransfer(direction,distanceToSurface);
    vec4 filtered=total/coverage;
    float confidence=smoothstep(0.003,0.035,coverage);
    if(confidence>=0.999) return filtered;
    return mix(celestialVolumeTransfer(direction,distanceToSurface),filtered,confidence);
}
#endif
