// A disjoint 3x2 half-resolution atlas. A history row is read only from
// the previous parity; the current parity is written by its owning lane.
// Never sample from the row being written. Reset on pack setup/resize.
layout(rgba16f) uniform image2D lwVolumeHistory;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform ivec3 previousCameraPositionInt;
uniform vec3 previousCameraPositionFract;
uniform float frameTime;

ivec2 volumeHistoryPixel(ivec2 p,ivec2 size,int slot,int parity) {
    return p+ivec2(slot*size.x,parity*size.y);
}
float volumeFrameTag(int frame) { return float((frame&1023)+1); }

vec4 temporalCelestialVolume(ivec2 p,ivec2 size,vec3 direction,float depth,bool volumeVisible) {
    vec3 sun=sunDirection();
    vec3 origin=vec3(cameraPositionInt)+cameraPositionFract;
    if(any(lessThan(imageSize(lwVolumeHistory),size*ivec2(3,2)))) {
        return volumeVisible ? celestialVolumeTransfer(direction,depth) : vec4(0,0,0,1);
    }
    int parity=frameCounter&1;
    int previousParity=1-parity;
    vec4 cloud=vec4(0,0,0,1);
    vec3 shaft=vec3(0);
    float windTime=mod(frameTimeCounter,64.0);
    float tag=volumeFrameTag(frameCounter);
    bool valid=false;
    vec4 priorCloud=vec4(0,0,0,1);
    vec4 priorShaft=vec4(0);
    vec3 delta=vec3(cameraPositionInt-previousCameraPositionInt)+cameraPositionFract-previousCameraPositionFract;
    bool stable=volumeVisible && frameTime>0.0 && frameTime<0.04 && dot(delta,delta)<0.0001;
    bool priorFresh=false;
    if(stable && frameCounter>0) {
        // Rotation-only ray reprojection avoids mixing near shafts and far
        // clouds with incompatible parallax. Translation is refreshed.
        if(dot(delta,delta)<0.0001) {
            vec4 clip=gbufferPreviousProjection*vec4(mat3(gbufferPreviousModelView)*direction,0.0);
            if(clip.w>0.0) {
                vec2 uv=clip.xy/clip.w*0.5+0.5;
                vec2 pixel=uv*vec2(size)-0.5;
                ivec2 donor=ivec2(floor(pixel+0.5));
                if(all(greaterThanEqual(donor,ivec2(0))) && all(lessThan(donor,size)) &&
                   length(pixel-vec2(donor))<0.35) {
                    vec4 meta=imageLoad(lwVolumeHistory,volumeHistoryPixel(donor,size,2,previousParity));
                    // Depth, time, weather and light direction compatibility.
                    if(abs(meta.a)==volumeFrameTag(frameCounter-1) &&
                       abs(meta.r-min(depth,640.0))<max(0.15,min(depth,640.0)*0.01) &&
                       abs(meta.g-sun.y)<0.002 && abs(meta.b-rainStrength)<0.005) {
                        priorShaft=imageLoad(lwVolumeHistory,volumeHistoryPixel(donor,size,1,previousParity));
                        valid=abs(priorShaft.a-windTime)<0.09;
                        if(valid) {
                            priorFresh=meta.a>0.0;
                            if(priorFresh) priorCloud=imageLoad(lwVolumeHistory,volumeHistoryPixel(donor,size,0,previousParity));
                        }
                    }
                }
            }
        }
    }
    bool reuseCloud=false;
    if(volumeVisible) {
        // Alternate coherent tiles. Only reuse cloud radiance for one frame:
        // the opposite parity always refreshes, regardless of history.
        reuseCloud=valid && priorFresh && (((p.x/8+p.y/8+frameCounter)&1)==0);
        cloud=reuseCloud ? priorCloud : cloudVolumeTransfer(origin,direction,sun,depth);
        // Always sample current shadows. Temporal smoothing only when the
        // fresh shaft is already close to history, so edits do not ghost.
        shaft=applyLightShafts(vec3(0),origin,direction,sun,depth);
        if(valid && all(lessThanEqual(abs(shaft-priorShaft.rgb),vec3(0.003)+abs(shaft)*0.08))) {
            shaft=mix(shaft,priorShaft.rgb,0.35);
        }
    }
    // Avoid full atlas traffic during translation/slow frames. Explicitly
    // invalidate the tag, including underwater frames, to prevent stale reuse.
    if(stable) {
        imageStore(lwVolumeHistory,volumeHistoryPixel(p,size,0,parity),cloud);
        imageStore(lwVolumeHistory,volumeHistoryPixel(p,size,1,parity),vec4(shaft,windTime));
    }
    imageStore(lwVolumeHistory,volumeHistoryPixel(p,size,2,parity),
        vec4(min(depth,640.0),sun.y,rainStrength,stable ? (reuseCloud ? -tag : tag) : 0.0));
    return vec4(cloud.rgb+shaft,cloud.a);
}
