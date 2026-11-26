#ifndef LW_EMITTER_PALETTE
#define LW_EMITTER_PALETTE

// Linear RGB artistic chromaticities, shared by visible emission and voxel light.
// Material IDs 10020..10023 remain reserved for opaque wall materials.
uint emitterKind(int blockId) {
    if (blockId >= 10011 && blockId <= 10019) return uint(blockId-10010);
    if (blockId >= 10024 && blockId <= 10029) return uint(blockId-10014);
    return 0u;
}

vec3 emitterColor(uint kind) {
    const vec3 colors[16] = vec3[16](
        vec3(1.0,0.72,0.42),    // unknown vanilla / mod emission
        vec3(1.0,0.58,0.24),    // torch
        vec3(0.14,0.70,1.0),    // soul
        vec3(0.58,0.88,1.0),    // sea lantern
        vec3(1.0,0.075,0.025),  // redstone torch
        vec3(1.0,0.23,0.038),   // lava
        vec3(1.0,0.79,0.46),    // glowstone
        vec3(1.0,0.52,0.19),    // redstone lamp
        vec3(0.95,0.69,1.0),    // pearlescent
        vec3(1.0,0.86,0.49),    // ochre
        vec3(0.55,1.0,0.48),    // verdant
        vec3(1.0,0.40,0.13),    // shroomlight
        vec3(1.0,0.50,0.16),    // jack o lantern
        vec3(0.83,0.89,1.0),    // end rod
        vec3(1.0,0.18,0.028),   // magma
        vec3(1.0,0.65,0.30)     // lantern
    );
    return colors[min(kind,15u)];
}

float emitterRadiance(uint kind) {
    // Magma and redstone indicator surfaces are intentionally dimmer.
    if (kind==4u) return 1.1;
    if (kind==14u) return 0.8;
    if (kind==5u) return 7.2;
    if (kind==6u || kind==8u || kind==9u || kind==10u || kind==11u || kind==12u || kind==13u) return 5.2;
    if (kind==1u || kind==2u || kind==15u) return 3.4;
    return 3.8;
}
#endif
