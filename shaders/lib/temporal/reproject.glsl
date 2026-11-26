uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

bool reprojectPosition(vec3 viewPosition, out vec2 previousUv, out float expectedDepth, mat4 previousProjection, bool sampleJitteredHistory) {
    vec3 cameraDelta = cameraPosition - previousCameraPosition;
    if (dot(cameraDelta, cameraDelta) > 16.0) {
        return false;
    }
    vec3 world = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec4 previousView = gbufferPreviousModelView * vec4(world + cameraDelta, 1.0);
    vec4 previousClip = previousProjection * previousView;
    if (previousClip.w <= 0.0) {
        return false;
    }
    expectedDepth = -previousView.z;
    previousUv = previousClip.xy / previousClip.w * 0.5 + 0.5;
#ifdef LW_TAA_ACTIVE
    if (sampleJitteredHistory) {
        previousUv += jitterOffset(frameCounter - 1);
    }
#endif
    return all(greaterThan(previousUv, vec2(0.0))) && all(lessThan(previousUv, vec2(1.0)));
}

// Resolved TAA colors live on the unjittered output grid; SSGI histories
// are written at raw G-buffer sample positions and retain previous jitter.
bool reprojectStableTerrain(vec3 viewPosition, out vec2 previousUv, out float expectedDepth, mat4 previousProjection) {
    return reprojectPosition(viewPosition, previousUv, expectedDepth, previousProjection, false);
}

bool reprojectTerrain(vec3 viewPosition, out vec2 previousUv, out float expectedDepth, mat4 previousProjection) {
    return reprojectPosition(viewPosition, previousUv, expectedDepth, previousProjection, true);
}

bool reprojectTerrain(vec3 viewPosition, out vec2 previousUv, out float expectedDepth) {
    return reprojectTerrain(viewPosition, previousUv, expectedDepth, gbufferPreviousProjection);
}

bool matchesHistoryDepth(float depth, float expectedDepth) {
    return depth > 0.0 && abs(depth - expectedDepth) <= max(0.07, expectedDepth * 0.012);
}
