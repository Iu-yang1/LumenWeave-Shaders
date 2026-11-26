#ifndef LW_SCENE_BUDGET_HELPER
#define LW_SCENE_BUDGET_HELPER
// A full mode is the user-selected sampling ceiling, not a performance cap.
// Require both distance fade and a small projected footprint before reducing.
bool lwReduceDistantWork(float depth,float distanceThreshold,float contribution,float footprint) {
#if SCENE_BUDGET == 1 && LW_DIMENSION_BUDGET != 0
    float footprintLimit=LW_DIMENSION_BUDGET==2 ? 42.0 : 28.0;
    #if defined(LW_DIMENSION_NETHER)
    // Caves contain narrow, high-contrast local-light boundaries.
    footprintLimit*=0.8;
    #elif defined(LW_DIMENSION_END)
    // Broad low-contrast terrain permits a larger spatial reuse region.
    footprintLimit*=1.15;
    #endif
    return depth>distanceThreshold && contribution<0.65 && footprint<footprintLimit;
#else
    return false;
#endif
}
#endif
