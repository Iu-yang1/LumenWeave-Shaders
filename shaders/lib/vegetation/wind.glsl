uniform float frameTimeCounter;
uniform float rainStrength;

vec3 vegetationDisplacement(vec3 position, vec2 stem, int materialId, float tip, float distanceToEye) {
    float reach = 1.0 - smoothstep(WIND_DISTANCE * 0.65, WIND_DISTANCE, distanceToEye);
    if (reach <= 0.0 || materialId < 10030 || materialId > 10033) {
        return vec3(0.0);
    }
    float time = frameTimeCounter * WIND_SPEED;
    vec2 phasePosition = materialId == 10030 ? position.xz : stem;
    float phase = dot(phasePosition, vec2(0.19, 0.13));
    float gust = 0.62 + 0.24 * sin(phase * 0.37 - time * 0.43);
    vec2 breeze = vec2(sin(phase - time * 1.1), sin(phase * 0.83 - time * 0.87 + 1.7));
    float strength = reach * WIND_STRENGTH * mix(1.0, 1.7, rainStrength);
#ifdef WAVING_LEAVES
    if (materialId == 10030) {
        float flutter = sin(dot(position, vec3(1.4, 1.1, 0.9)) - time * 2.8);
        return vec3(breeze.x, flutter * 0.3, breeze.y) * (0.045 * gust * strength);
    }
#endif
#ifdef WAVING_GRASS
    if (materialId >= 10031) {
        float height = materialId == 10032 ? tip * 0.5
            : (materialId == 10033 ? 0.5 + tip * 0.5 : tip);
        vec2 bend = (vec2(0.8, 0.35) + breeze * 0.45) * (0.18 * gust * height * height * strength);
        return vec3(bend.x, -dot(bend, bend) * 0.25, bend.y);
    }
#endif
    return vec3(0.0);
}
