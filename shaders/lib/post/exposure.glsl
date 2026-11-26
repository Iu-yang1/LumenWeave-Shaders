#ifdef AUTO_EXPOSURE
#ifdef LW_EXPOSURE_METER
uniform sampler2D lwExposureSampler;
float lwExposureEV(){
    vec4 state=texelFetch(lwExposureSampler,ivec2(0),0);
#ifdef LW_EXPOSURE_FINAL
    // Bloom already used R before composite4 advanced the history.
    return state.g;
#else
    return state.r;
#endif
}
#else
uniform ivec2 eyeBrightnessSmooth;
float lwExposureEV(){
    vec2 light=clamp(vec2(eyeBrightnessSmooth)/240.0,0.0,1.0);
    return clamp(0.8-1.15*max(light.x,light.y),-0.5,0.8)*EXPOSURE_ADAPTATION;
}
#endif
#else
float lwExposureEV(){return 0.0;}
#endif
