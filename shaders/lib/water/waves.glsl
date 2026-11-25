vec2 waterWaveSlope(vec2 position, vec2 footprintX, vec2 footprintY, float time, float elapsed) {
    const vec2 directions[8] = vec2[8](
        vec2(0.940, 0.342), vec2(0.643, 0.766),
        vec2(0.996, -0.087), vec2(0.342, 0.940),
        vec2(0.819, -0.574), vec2(-0.174, 0.985),
        vec2(0.985, 0.174), vec2(0.500, -0.866)
    );
    const float wavelengths[8] = float[8](14.0, 8.7, 5.3, 3.2, 1.9, 1.1, 0.63, 0.36);
    const float steepness[8] = float[8](0.047, 0.043, 0.039, 0.035, 0.030, 0.025, 0.020, 0.015);
    vec2 slope = vec2(0.0);
#ifdef LITE_LIGHTING
    const int waveCount = 4;
#else
    const int waveCount = 8;
#endif
    for (int wave = 0; wave < waveCount; ++wave) {
        vec2 waveVector = directions[wave] * (6.2831853 / wavelengths[wave]);
        float frequency = sqrt(9.81 * length(waveVector)) * 0.65;
        float phase = dot(position, waveVector) - frequency * time + float(wave) * 2.3999632;
        vec2 coverage = vec2(dot(footprintX, waveVector), dot(footprintY, waveVector));
        float variance = dot(coverage, coverage) + pow(frequency * elapsed, 2.0);
        float resolved = exp(-0.5 * variance);
        slope += directions[wave] * (steepness[wave] * cos(phase) * resolved);
    }
    return slope;
}
