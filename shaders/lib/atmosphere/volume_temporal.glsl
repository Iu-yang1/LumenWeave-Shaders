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
// Translation reuse is restricted to the entire distant cloud slab.
bool fullCloudSlab(float height,vec3 direction,float depth,out vec2 interval){
    interval=vec2(0.0);
    if(abs(direction.y)<0.05) return false;
    vec2 t=(vec2(156.0,174.0)-height)/direction.y;
    interval=vec2(min(t.x,t.y),max(t.x,t.y));
    return interval.x>=32.0 && interval.y<=min(depth,630.0)-2.0;
}

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
    bool rotationOnly=dot(delta,delta)<0.0001;
    bool recordable=volumeVisible && frameTime>0.0 && frameTime<0.04;
    bool stable=recordable && rotationOnly;
    bool translated=false;
    vec2 interval=vec2(0.0),previousInterval=vec2(0.0);
    vec3 previousDirection=direction;
#if APPROX_REUSE == 1
    if(recordable && !rotationOnly && dot(delta,delta)<1.0 && fullCloudSlab(origin.y,direction,depth,interval)){
        float anchor=0.5*(interval.x+interval.y);
        // Wind advection aligns the density coordinates at the middle of the slab.
        vec3 wind=vec3(1.1,0.0,0.40)*frameTime;
        previousDirection=normalize(direction*anchor+delta+wind);
        float span=interval.y-interval.x;
        // Bound parallax mismatch across the slab, not only at the anchor.
        translated=length(delta+wind)*span/(2.0*anchor)<0.35 &&
            fullCloudSlab(origin.y-delta.y,previousDirection,640.0,previousInterval);
    }
#endif
    bool historyAllowed=stable || translated;
    bool priorFresh=false;
    bool reuseTile=(((p.x/8+p.y/8+frameCounter)&1)==0);
    if(historyAllowed && frameCounter>0) {
        {
            vec4 clip=gbufferPreviousProjection*vec4(mat3(gbufferPreviousModelView)*previousDirection,0.0);
            if(clip.w>0.0) {
                vec2 uv=clip.xy/clip.w*0.5+0.5;
#ifdef LW_GEOMETRY_TAAU
                uv+=jitterOffset(frameCounter-1);
#endif
                vec2 pixel=uv*vec2(size)-0.5;
                ivec2 donor=ivec2(floor(pixel+0.5));
                if(all(greaterThanEqual(donor,ivec2(0))) && all(lessThan(donor,size)) &&
                   length(pixel-vec2(donor))<0.35) {
                    // Projected donor rounding can add spatial error at long range.
                    float angularPixel=2.0*length((pixel-vec2(donor))/(vec2(size)*max(abs(vec2(gbufferPreviousProjection[0][0],gbufferPreviousProjection[1][1])),vec2(0.01))));
                    bool donorAligned=!translated || angularPixel*previousInterval.y<0.45;
                    vec4 meta=imageLoad(lwVolumeHistory,volumeHistoryPixel(donor,size,2,previousParity));
                    // Depth, time, weather and light direction compatibility.
                    bool depthCompatible=translated ? meta.r>previousInterval.y+2.0 :
                        abs(meta.r-min(depth,640.0))<max(0.15,min(depth,640.0)*0.01);
                    if(donorAligned && abs(meta.a)==volumeFrameTag(frameCounter-1) && depthCompatible &&
                       abs(meta.g-sun.y)<0.002 && abs(meta.b-rainStrength)<0.005) {
                        priorShaft=imageLoad(lwVolumeHistory,volumeHistoryPixel(donor,size,1,previousParity));
                        valid=abs(priorShaft.a-windTime)<0.09;
                        if(valid) {
                            priorFresh=meta.a>0.0;
                            if(priorFresh && reuseTile) priorCloud=imageLoad(lwVolumeHistory,volumeHistoryPixel(donor,size,0,previousParity));
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
        reuseCloud=valid && priorFresh && reuseTile;
        cloud=reuseCloud ? priorCloud : cloudVolumeTransfer(origin,direction,sun,depth);
        // Always sample current shadows. Temporal smoothing only when the
        // fresh shaft is already close to history, so edits do not ghost.
        shaft=applyLightShafts(vec3(0),origin,direction,sun,depth);
        if(stable && valid && all(lessThanEqual(abs(shaft-priorShaft.rgb),vec3(0.003)+abs(shaft)*0.08))) {
            shaft=mix(shaft,priorShaft.rgb,0.35);
        }
    }
    // Write fresh full-slab moving cloud history; never reuse a translated shaft.
    // Invalidate unsupported motion and underwater history explicitly.
    if(historyAllowed) {
        // A negative freshness tag forbids reading reused cloud RGB next frame.
        if(!reuseCloud) imageStore(lwVolumeHistory,volumeHistoryPixel(p,size,0,parity),cloud);
        imageStore(lwVolumeHistory,volumeHistoryPixel(p,size,1,parity),vec4(shaft,windTime));
    }
    imageStore(lwVolumeHistory,volumeHistoryPixel(p,size,2,parity),
        vec4(min(depth,640.0),sun.y,rainStrength,historyAllowed ? (reuseCloud ? -tag : tag) : 0.0));
    return vec4(cloud.rgb+shaft,cloud.a);
}
