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
    // Exact unpolarized dielectric Fresnel for both directions.
    float n1=submerged ? 1.333 : 1.0;
    float n2=submerged ? 1.0 : 1.333;
    float ci=clamp(cosine,0.0,1.0);
    float eta=n1/n2;
    float st2=eta*eta*(1.0-ci*ci);
    if(st2>=1.0) return 1.0;
    float ct=sqrt(max(0.0,1.0-st2));
    float rs=(n1*ci-n2*ct)/max(n1*ci+n2*ct,0.00001);
    float rp=(n2*ci-n1*ct)/max(n2*ci+n1*ct,0.00001);
    return 0.5*(rs*rs+rp*rp);
}

vec3 waterToAirDirection(vec3 incident, vec3 normal) {
    return refract(incident, normal, 1.333);
}

#endif
