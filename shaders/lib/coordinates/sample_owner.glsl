#ifndef LW_SAMPLE_OWNER
#define LW_SAMPLE_OWNER
// Only geometry that actually applied projection jitter writes this attachment.
// Depth comparison prevents stale terrain metadata from claiming unjittered entities.
uniform sampler2D colortex3;

int sampleOwner(vec2 uv, float depth, bool distant) {
    vec2 metadata = texelFetch(colortex3, depthPixelAtUv(colortex3, uv), 0).rg;
    int kind = int(metadata.y + 0.5);
    bool native = kind == 1 || kind == 2 || kind == 5;
    bool dh = kind == 3 || kind == 4;
    if ((distant ? !dh : !native) || abs(metadata.x - depth) > 0.00000012) {
        return 0;
    }
    return kind;
}
#endif
