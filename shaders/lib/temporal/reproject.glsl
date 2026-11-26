uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

bool reprojectTerrain(vec3 viewPosition, out vec2 previousUv, out float expectedDepth, mat4 previousProjection) {
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
    previousUv += jitterOffset(frameCounter - 1);
#endif
    return all(greaterThan(previousUv, vec2(0.0))) && all(lessThan(previousUv, vec2(1.0)));
}

bool reprojectTerrain(vec3 viewPosition, out vec2 previousUv, out float expectedDepth) {
    return reprojectTerrain(viewPosition, previousUv, expectedDepth, gbufferPreviousProjection);
}

bool matchesHistoryDepth(float depth, float expectedDepth) {
    return depth > 0.0 && abs(depth - expectedDepth) <= max(0.07, expectedDepth * 0.012);
}
