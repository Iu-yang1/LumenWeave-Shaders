#ifndef LW_PACKED_VOXEL_FIELD
#define LW_PACKED_VOXEL_FIELD
// Fused stage zero contains only a 9-bit seed. Reproduce its original half
// conversion before the first Jacobi iteration.
vec4 lwFieldHalf(vec4 value) {
    return vec4(unpackHalf2x16(packHalf2x16(value.xy)),
                unpackHalf2x16(packHalf2x16(value.zw)));
}
vec4 lwDecodeSource(uint seed) {
    if (seed == 0u || seed >= LW_VOXEL_WALL) return vec4(0.0);
    vec3 color=voxelSeedEmission(seed);
    return lwFieldHalf(vec4(color,float(any(greaterThan(color,vec3(0.0))))));
}
// Stage 2 has exactly four possible support states: zero and distances
// 0, 1, 2 from an emitter. Encode support independently of RGB.
uint lwPackStage2(vec4 light) {
    uvec3 q=uvec3(round(sqrt(clamp(light.rgb*0.5,0.0,1.0))*1023.0));
    uint support=light.a>0.9?3u:(light.a>0.7?2u:(light.a>0.0?1u:0u));
    return q.x | (q.y<<10u) | (q.z<<20u) | (support<<30u);
}
vec4 lwUnpackStage2(uint word) {
    vec3 q=vec3(uvec3(word,word>>10u,word>>20u)&1023u)/1023.0;
    const float support[4]=float[4](0.0,0.599609375,0.7998046875,1.0);
    return vec4(2.0*q*q,support[word>>30u]);
}
#endif
