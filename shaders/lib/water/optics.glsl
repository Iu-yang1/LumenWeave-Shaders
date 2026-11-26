#ifndef LW_WATER_OPTICS
#define LW_WATER_OPTICS

vec3 waterExtinction() {
    // Scene-calibrated Beer-Lambert extinction, in inverse blocks.
    return vec3(0.115, 0.028, 0.012) * WATER_DENSITY + vec3(WATER_TURBIDITY);
}

vec3 waterScatteringColor(vec3 biome) {
    return mix(vec3(0.032, 0.125, 0.145), biome * 0.26, WATER_BIOME_TINT);
}

float waterFresnel(float cosine, bool submerged) {
    if (submerged) {
        float transmittedSineSquared = 1.777 * (1.0 - cosine * cosine);
        if (transmittedSineSquared >= 1.0) {
            return 1.0;
        }
        cosine = sqrt(1.0 - transmittedSineSquared);
    }
    float complement = 1.0 - cosine;
    float fifth = complement * complement;
    fifth *= fifth * complement;
    return 0.0204 + 0.9796 * fifth;
}

vec3 waterToAirDirection(vec3 incident, vec3 normal) {
    return refract(incident, normal, 1.333);
}

#endif
