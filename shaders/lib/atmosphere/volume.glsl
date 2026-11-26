uniform float frameTimeCounter;
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

float cloudHash(vec2 cell) {
    vec3 hash = fract(vec3(cell.xyx) * 0.1031);
    hash += dot(hash, hash.yzx + 33.33);
    return fract((hash.x + hash.y) * hash.z);
}

float cloudNoise(vec2 position) {
    vec2 cell = floor(position);
    vec2 blend = fract(position);
    blend = blend * blend * (3.0 - 2.0 * blend);
    vec2 high = vec2(cloudHash(cell + vec2(0.0, 1.0)), cloudHash(cell + vec2(1.0, 1.0)));
    vec2 low = vec2(cloudHash(cell), cloudHash(cell + vec2(1.0, 0.0)));
    return mix(mix(low.x, low.y, blend.x), mix(high.x, high.y, blend.x), blend.y);
}

float cloudDensity(vec3 position) {
    float height = (position.y - 156.0) / 18.0;
    float layer = smoothstep(0.0, 0.24, height) * (1.0 - smoothstep(0.55, 1.0, height));
    if (layer <= 0.0) return 0.0;
    vec2 uv = (position.xz + frameTimeCounter * vec2(1.1, 0.40)) * 0.017;
    float threshold=mix(0.48,0.34,rainStrength);
    // Noise is in [0,1]. The unfinished octave sum has a known upper
    // bound, so empty cloud regions can skip finer noise exactly.
    float shape=0.65*cloudNoise(uv);
    if(shape+0.35<=threshold) return 0.0;
    shape+=0.25*cloudNoise(uv*2.07);
    if(shape+0.10<=threshold) return 0.0;
    shape+=0.10*cloudNoise(uv*5.0);
    return layer*smoothstep(threshold,0.78,shape);
}

vec4 cloudVolumeTransfer(vec3 origin, vec3 direction, vec3 sun, float maxDistance) {
    if (!hasSkylight) {
        return vec4(0.0,0.0,0.0,1.0);
    }
    if (abs(direction.y) <= 0.003) {
        return vec4(0.0,0.0,0.0,1.0);
    }
    vec2 distances = (vec2(156.0, 174.0) - origin.y) / direction.y;
    float start = max(min(distances.x, distances.y), 0.0);
    float end = min(max(distances.x, distances.y), min(maxDistance, 640.0));
    if (end <= start || start >= 630.0) {
        return vec4(0.0,0.0,0.0,1.0);
    }
    float span=end-start;
    // A short visible segment or distant subpixel cloud layer does not need
    // all configured taps. Long nearby visible paths retain the full budget.
    int steps=start<128.0 ? CLOUD_STEPS : clamp(int(ceil(span/2.5)),min(4,CLOUD_STEPS),CLOUD_STEPS);
    float stepSize = span / float(steps);
    float day = daylight(sun);
    vec3 tint = sunTint(sun);
    float transmission = 1.0;
    vec3 scattering = vec3(0.0);
    for (int tap = 0; tap < steps; ++tap) {
        vec3 point = origin + direction * (start + (float(tap) + 0.5) * stepSize);
        float density = cloudDensity(point);
        if (density <= 0.0) {
            continue;
        }
        float opacity = 1.0 - exp(-density * stepSize * 0.15);
        vec3 radiance=vec3(0.044,0.052,0.074);
        if(day>0.0) {
            float light=exp(-2.6*cloudDensity(point+sun*6.0));
            vec3 dayCloud=vec3(0.41,0.48,0.58)+tint*light*0.58;
            radiance=mix(radiance,dayCloud,day);
        }
        radiance *= 1.0 - rainStrength * 0.28;
        scattering += radiance * transmission * opacity;
        transmission *= 1.0 - opacity;
        if (transmission < 0.015) {
            break;
        }
    }
    float coverage=1.0-smoothstep(410.0,630.0,start);
    return vec4(scattering*coverage,mix(1.0,transmission,coverage));
}

vec3 applyCloudVolume(vec3 scene,vec3 origin,vec3 direction,vec3 sun,float maxDistance) {
    vec4 transfer=cloudVolumeTransfer(origin,direction,sun,maxDistance);
    return scene*transfer.a+transfer.rgb;
}

vec3 applyLightShafts(vec3 scene, vec3 origin, vec3 direction, vec3 sun, float maxDistance) {
    if (!hasSkylight) {
        return scene;
    }
    float day = smoothstep(0.0, 0.2, sun.y) * (1.0 - rainStrength);
    float cosine = max(dot(direction, sun), 0.0);
    float phase = 0.025 + 0.975 * pow(cosine, 6.0);
    if (day <= 0.0 || maxDistance <= 0.001 || phase * day < 0.008) {
        return scene;
    }
    float span=min(maxDistance,36.0);
    int steps=clamp(int(ceil(span/5.0)),min(2,SHAFT_STEPS),SHAFT_STEPS);
    float stepSize = span / float(steps);
    float density = 0.0;
    for (int tap = 0; tap < steps; ++tap) {
        vec3 offset = direction * ((float(tap) + 0.5) * stepSize);
        float altitude = origin.y + offset.y;
        float sunlight = 1.0;
#ifdef SCENE_SHADOWS
        sunlight = volumeShadow(offset);
#endif
        density += sunlight * exp(-max(altitude - 63.0, 0.0) * 0.019);
    }
    return scene + celestialIrradiance(sun) * (density * stepSize * phase * day * (0.008 / 3.1));
}
