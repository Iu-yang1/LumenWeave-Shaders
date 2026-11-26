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
vec2 lwWaterSlopeTexture(vec2 uv) {
    return textureLod(lwWaterNormal,(fract(uv)*64.0+1.0)/66.0,0.0).rg-0.5;
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
        float phase = dot(position, waveVector) - frequency * time * WATER_WAVE_SPEED + float(wave) * 2.3999632;
        vec2 coverage = vec2(dot(footprintX, waveVector), dot(footprintY, waveVector));
        float temporalCoverage = frequency * elapsed * WATER_WAVE_SPEED;
        float variance = dot(coverage, coverage) + temporalCoverage * temporalCoverage;
#ifdef LITE_LIGHTING
        float resolved = 1.0 / (1.0 + 0.5 * variance);
#else
        float resolved = exp(-0.5 * variance);
#endif
        // Fade unresolved waves smoothly before evaluating their trigonometry.
        float coverageWeight = smoothstep(0.002, 0.012, resolved);
        if (coverageWeight > 0.0) {
            slope += directions[wave] * (steepness[wave] * waterPhaseCos(phase) * resolved * coverageWeight);
        }
    }
#if WATER_HYBRID_WAVES == 1
    float footprint=max(length(footprintX),length(footprintY));
    if(WATER_WAVE_DETAIL>=4 && footprint<1.2) {
        vec2 uv=position*0.032+time*WATER_WAVE_SPEED*vec2(0.013,-0.008);
        vec2 fine=lwWaterSlopeTexture(uv);
        slope+=fine*0.065*(1.0-smoothstep(0.12,1.2,footprint));
        if(WATER_WAVE_DETAIL>=8 && footprint<0.45) {
            vec2 uv2=position.yx*0.071-time*WATER_WAVE_SPEED*vec2(0.019,0.012);
            slope+=lwWaterSlopeTexture(uv2)*0.045*(1.0-smoothstep(0.04,0.45,footprint));
        }
    }
#endif
    return slope * WATER_WAVE_STRENGTH;
}

#if RAIN_RIPPLES > 0
vec2 rainRippleSlope(vec2 position,float time,float footprint) {
    if(footprint>=0.35) return vec2(0.0);
    vec2 p=position*2.5, cell=floor(p), local=fract(p);
    vec2 result=vec2(0.0);
    for(int y=-1;y<=1;++y) for(int x=-1;x<=1;++x) {
#if RAIN_RIPPLES == 1
        if(abs(x)+abs(y)>1) continue;
#endif
        vec2 offset=vec2(x,y);
        vec2 h=fract(sin(vec2(dot(cell+offset,vec2(127.1,311.7)),dot(cell+offset,vec2(269.5,183.3))))*43758.5453);
        vec2 delta=local-offset-h;
        float d=length(delta), age=fract(time*1.25+h.x);
        float ring=d-age*0.85;
        float envelope=smoothstep(0.0,0.12,age)*(1.0-smoothstep(0.60,1.0,age))*(1.0-smoothstep(0.02,0.16,abs(ring)));
        result+=delta/max(d,0.001)*sin(ring*35.0)*envelope;
    }
    return result*0.075*(1.0-smoothstep(0.06,0.35,footprint));
}
#endif
