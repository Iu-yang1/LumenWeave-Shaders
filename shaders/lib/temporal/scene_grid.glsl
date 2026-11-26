#ifndef LW_SCENE_GRID
#define LW_SCENE_GRID
ivec2 lwSceneRenderSize(ivec2 displaySize) {
    return max(displaySize*SCENE_TAAU_SCALE/100,ivec2(1));
}
vec2 lwScenePhase(int frame) {
    const vec2 samples[8]=vec2[8](vec2(-0.375,-0.125),vec2(0.125,0.375),vec2(0.375,-0.375),vec2(-0.125,0.125),vec2(0.375,0.125),vec2(-0.125,-0.375),vec2(-0.375,0.375),vec2(0.125,-0.125));
    return samples[frame&7];
}
ivec2 lwSceneDonorPixel(ivec2 lowPixel,ivec2 fullSize,int frame) {
    vec2 outputUv=(vec2(lowPixel)+0.5+lwScenePhase(frame))/vec2(lwSceneRenderSize(fullSize));
    return clamp(ivec2(outputUv*vec2(fullSize)),ivec2(0),fullSize-1);
}
vec2 lwSceneLowCoord(vec2 outputUv,ivec2 fullSize,int frame) {
    return outputUv*vec2(lwSceneRenderSize(fullSize))-lwScenePhase(frame)-0.5;
}
ivec2 lwSceneNearest(vec2 outputUv,ivec2 fullSize,int frame) {
    return clamp(ivec2(floor(lwSceneLowCoord(outputUv,fullSize,frame)+0.5)),ivec2(0),lwSceneRenderSize(fullSize)-1);
}
#endif
