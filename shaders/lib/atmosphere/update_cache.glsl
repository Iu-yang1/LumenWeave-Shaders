// All consumers use the same immutable previous state during begin1/2.
// begin3 publishes only after both dependent LUT dispatches have finished.
#ifdef LW_ATMO_CACHE_ACTIVE
layout(rgba32f) uniform image2D lwAtmoState;
uniform float frameTimeCounter;
bool atmoUpdateNeeded(float height,float sunMu) {
    vec4 old=imageLoad(lwAtmoState,ivec2(0));
    float age=frameTimeCounter-old.z;
    // No physical sky contribution at night. At sunrise the last daytime
    // state must be refreshed before either LUT is used.
    if(sunMu<=-0.15) return false;
    float threshold=mix(0.00025,0.002,smoothstep(0.02,0.35,sunMu));
    return old.w<0.5 || abs(height-old.x)>0.25 || abs(sunMu-old.y)>threshold
        || age<0.0 || age>0.10;
}
#endif
