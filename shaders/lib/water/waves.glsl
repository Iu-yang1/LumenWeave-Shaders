#if WATER_PHASE_LUT == 1
uniform sampler2D lwWaterPhase;
float waterPhaseCos(float phase) {
    // Preserve native argument reduction for distant world coordinates.
    if(abs(phase)>2048.0) return cos(phase);
    return textureLod(lwWaterPhase,vec2((fract(phase/6.2831853)*256.0+0.5)/257.0,0.5),0.0).r;
}
#else
float waterPhaseCos(float phase) { return cos(phase); }
#endif
#if WATER_HYBRID_WAVES == 1
uniform sampler2D lwWaterNormal;
// One-pixel periodic gutters make bilinear filtering continuous even on
// loaders which clamp raw custom textures. The footprint fades fine bands.
vec2 lwWaterSlopeTexture(vec2 uv,float footprint) {
    vec2 p=fract(uv);
    float level=smoothstep(0.60,2.0,footprint*64.0);
    vec2 size=vec2(66.0,100.0);
    vec2 fineUv=(p*64.0+1.0)/size;
    vec2 coarseUv=(p*32.0+vec2(1.0,67.0))/size;
    if(level<=0.0) return textureLod(lwWaterNormal,fineUv,0.0).rg-0.5;
    if(level>=1.0) return textureLod(lwWaterNormal,coarseUv,0.0).rg-0.5;
    return mix(textureLod(lwWaterNormal,fineUv,0.0).rg,textureLod(lwWaterNormal,coarseUv,0.0).rg,level)-0.5;
}
#endif
vec2 waterWaveSlope(vec2 position, vec2 footprintX, vec2 footprintY, float time, float elapsed) {
    const vec2 directions[8] = vec2[8](
        vec2(0.940, 0.342), vec2(0.643, 0.766),
        vec2(0.996, -0.087), vec2(0.342, 0.940),
        vec2(0.819, -0.574), vec2(-0.174, 0.985),
        vec2(0.985, 0.174), vec2(0.500, -0.866)
    );
    const vec2 waveVectors[8]=vec2[8](vec2(0.421871013,0.153489241),vec2(0.464377948,0.553209188),vec2(1.180764634,-0.103139079),vec2(0.671515429,1.845685682),vec2(2.708383558,-1.898183349),vec2(-0.993885675,5.626306837),vec2(9.823710350,1.735355940),vec2(8.726646250,-15.114551305));
    const float frequencies[8]=float[8](1.364064777,1.730216396,2.216433941,2.853146181,3.702428861,4.866265874,6.430161803,8.505145871);
    const float steepness[8] = float[8](0.047, 0.043, 0.039, 0.035, 0.030, 0.025, 0.020, 0.015);
    vec2 slope = vec2(0.0);
#if WATER_HYBRID_WAVES == 1
    int analyticWaves=min(WATER_WAVE_DETAIL,4);
#else
    int analyticWaves=WATER_WAVE_DETAIL;
#endif
    for (int wave = 0; wave < analyticWaves; ++wave) {
        vec2 waveVector=waveVectors[wave];
        float frequency=frequencies[wave];
        vec2 coverage = vec2(dot(footprintX, waveVector), dot(footprintY, waveVector));
        float temporalCoverage = frequency * elapsed * WATER_WAVE_SPEED;
        float variance = dot(coverage, coverage) + temporalCoverage * temporalCoverage;
#ifdef LITE_LIGHTING
        if (variance >= 1000.0) continue;
        float resolved = 1.0 / (1.0 + 0.5 * variance);
#else
        if (variance >= 12.5) continue;
        float resolved = exp(-0.5 * variance);
#endif
        // Fade unresolved waves smoothly before evaluating their trigonometry.
        float coverageWeight = smoothstep(0.002, 0.012, resolved);
        if (coverageWeight > 0.0) {
            float phase = dot(position, waveVector) - frequency * time * WATER_WAVE_SPEED + float(wave) * 2.3999632;
            slope += directions[wave] * (steepness[wave] * waterPhaseCos(phase) * resolved * coverageWeight);
        }
    }
#if WATER_HYBRID_WAVES == 1
    float footprint=sqrt(max(dot(footprintX,footprintX),dot(footprintY,footprintY)));
    if(WATER_WAVE_DETAIL>=4 && footprint<1.2) {
        vec2 uv=position*0.032+time*WATER_WAVE_SPEED*vec2(0.013,-0.008);
        vec2 fine=lwWaterSlopeTexture(uv,footprint*0.032);
        slope+=fine*0.065*(1.0-smoothstep(0.12,1.2,footprint));
        if(WATER_WAVE_DETAIL>=8 && footprint<0.45) {
            vec2 uv2=position.yx*0.071-time*WATER_WAVE_SPEED*vec2(0.019,0.012);
            slope+=lwWaterSlopeTexture(uv2,footprint*0.071)*0.045*(1.0-smoothstep(0.04,0.45,footprint));
        }
    }
#endif
    return slope * WATER_WAVE_STRENGTH;
}

#include "/lib/weather/ripples.glsl"
