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

float proceduralCloudNoise(vec2 position) {
    vec2 cell = floor(position);
    vec2 blend = fract(position);
    blend = blend * blend * (3.0 - 2.0 * blend);
    vec2 high = vec2(cloudHash(cell + vec2(0.0, 1.0)), cloudHash(cell + vec2(1.0, 1.0)));
    vec2 low = vec2(cloudHash(cell), cloudHash(cell + vec2(1.0, 0.0)));
    return mix(mix(low.x, low.y, blend.x), mix(high.x, high.y, blend.x), blend.y);
}

#if CLOUD_NOISE_MODE == 1
uniform sampler2D lwCloudNoise;
#endif
float cloudNoise(vec2 position) {
#if CLOUD_NOISE_MODE == 1
    // 255 periodic lattice cells, four samples/cell and a two-texel pad.
    // Manual coordinate wrapping works even with clamped raw textures.
    return textureLod(lwCloudNoise,(mod(position,255.0)*4.0+2.5)/1024.0,0.0).r;
#else
    return proceduralCloudNoise(position);
#endif
}
vec2 cloudNoisePosition(vec3 position) {
    return (position.xz+frameTimeCounter*vec2(1.1,0.40))*0.017;
}
float cloudDensityCoarse(vec3 position,float detail,vec2 uv,float coarse) {
    float height = (position.y - 156.0) / 18.0;
    float layer = smoothstep(0.0, 0.24, height) * (1.0 - smoothstep(0.55, 1.0, height));
    if (layer <= 0.0) return 0.0;
    float threshold=mix(0.48,0.34,rainStrength);
    // Noise is in [0,1]. The unfinished octave sum has a known upper
    // bound, so empty cloud regions can skip finer noise exactly.
    float shape=0.65*coarse;
    if(shape+0.35<=threshold) return 0.0;
    shape+=0.25*cloudNoise(uv*2.07);
    if(shape+0.10<=threshold) return 0.0;
    // Blend high-frequency noise toward its mean at subpixel footprints.
    shape+=0.10*(detail<=0.001 ? 0.5 : mix(0.5,cloudNoise(uv*5.0),detail));
    return layer*smoothstep(threshold,0.78,shape);
}

float cloudDensity(vec3 position,float detail) {
    if(position.y<=156.0 || position.y>=174.0) return 0.0;
    vec2 uv=cloudNoisePosition(position);
    return cloudDensityCoarse(position,detail,uv,cloudNoise(uv));
}
float cloudDensity(vec3 position) { return cloudDensity(position,1.0); }

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
#if LW_DIMENSION_BUDGET == 0
    int steps=CLOUD_STEPS;
#elif LW_DIMENSION_BUDGET == 2
    int steps=start<128.0 ? CLOUD_STEPS : clamp(int(ceil(span/3.5)),min(4,CLOUD_STEPS),CLOUD_STEPS);
#else
    int steps=start<128.0 ? CLOUD_STEPS : clamp(int(ceil(span/2.5)),min(4,CLOUD_STEPS),CLOUD_STEPS);
#endif
#if CLOUD_ADAPTIVE == 1 && LW_DIMENSION_BUDGET != 0
    float targetStep=mix(3.0,1.6,smoothstep(0.1,0.9,abs(direction.y)));
    targetStep*=mix(1.0,1.45,smoothstep(128.0,550.0,start));
    targetStep*=LW_DIMENSION_BUDGET==2 ? 1.25 : 1.0;
    // Inside/near the layer, never reduce the existing maximum.
    steps=start<18.0 ? CLOUD_STEPS : clamp(int(ceil(span/targetStep)),min(4,CLOUD_STEPS),CLOUD_STEPS);
#endif
    float stepSize = span / float(steps);
    float day = daylight(sun);
    vec3 tint = sunTint(sun);
    float transmission = 1.0;
    vec3 scattering = vec3(0.0);
    float detail=1.0;
#if CLOUD_ADAPTIVE == 1 && LW_DIMENSION_BUDGET != 0
    // Fade the highest octave only when the ray or pixel footprint
    // undersamples its ~11.8-block lattice and the cloud is distant.
    float rayFootprint=length(direction.xz)*stepSize;
    float pixelFootprint=2.0*abs(gbufferProjectionInverse[1][1])*start/max(float(textureSize(depthtex0,0).y),1.0);
    detail=1.0-smoothstep(128.0,400.0,start)*smoothstep(0.25,0.65,max(rayFootprint,pixelFootprint)*0.085);
#endif
    vec3 rayStep=direction*stepSize;
    vec3 point=origin+direction*(start+0.5*stepSize);
    float previousDensity=-1.0;
    float previousLight=1.0;
    int lastLightTap=-2;
    for(int tap=0;tap<steps;++tap,point+=rayStep) {
#if CLOUD_EMPTY_SKIP == 1 && CLOUD_NOISE_MODE == 1
        // Coarse octave is Lipschitz bounded by 2.3 in lattice coordinates.
        // If even the upper bound at the NEXT midpoint is below threshold
        // with both remaining octaves at one, both samples are exactly empty.
        vec2 uv=cloudNoisePosition(point);
        float coarse=cloudNoise(uv);
        if(tap+1<steps) {
            float upper=0.65*min(1.0,coarse+2.3*length(rayStep.xz)*0.017)+0.35;
            if(upper<=mix(0.48,0.34,rainStrength)) {
                ++tap;
                point+=rayStep;
                continue;
            }
        }
        float density=cloudDensityCoarse(point,detail,uv,coarse);
#else
        float density=cloudDensity(point,detail);
#endif
        if (density <= 0.0) {
            continue;
        }
        float opacity = 1.0 - exp(-density * stepSize * 0.15);
        vec3 radiance=vec3(0.044,0.052,0.074);
        if(day>0.0) {
            float light;
#if CLOUD_LIGHT_REUSE == 1 && LW_DIMENSION_BUDGET != 0
            // Reuse at most one adjacent light query where both the density
            // and spatial displacement are small. Never cross an empty gap.
            if(tap==lastLightTap+1 && abs(density-previousDensity)<0.025 &&
               length(rayStep)<1.8 && start>80.0) {
                light=previousLight;
            } else {
                light=exp(-2.6*cloudDensity(point+sun*6.0,detail));
                previousLight=light;
                previousDensity=density;
                lastLightTap=tap;
            }
#else
            light=exp(-2.6*cloudDensity(point+sun*6.0,detail));
#endif
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
    int extraSamples=max(0,SHAFT_STEPS-steps);
#if SHAFT_ADAPTIVE == 1 && LW_DIMENSION_BUDGET != 0
    // Weak phase contribution uses fewer samples, but keep the full
    // baseline near the sun / strong shafts. Short spans need fewer taps.
    if(phase*day<0.06 && span>12.0) steps=max(2,steps-2);
    // Reserve two comparisons for boundary refinement on strong rays.
    if(phase*day>0.12 && steps>=4) steps=max(2,steps-2);
    extraSamples=max(0,SHAFT_STEPS-steps);
#endif
    float stepSize=span/float(steps);
    float density=0.0;
    vec3 rayStep=direction*stepSize;
    vec3 offset=0.5*rayStep;
#ifdef SCENE_SHADOWS
    mat4 toShadow=shadowProjection*shadowModelView;
    vec4 clipStart=toShadow*vec4(offset,1.0);
    vec4 clipStep=toShadow*vec4(rayStep,0.0);
#endif
    float altitude=origin.y+offset.y;
    float deltaHeight=rayStep.y;
    float heightDecay=exp(-deltaHeight*0.019);
    float airDensity=exp(-max(altitude-63.0,0.0)*0.019);
    float previousSunlight=-1.0;
    for(int tap=0;tap<steps;++tap) {
        float sunlight=1.0;
#ifdef SCENE_SHADOWS
        vec4 clip=clipStart+float(tap)*clipStep;
        sunlight=volumeShadowProjected(clip.xyz/clip.w*0.5+0.5);
#endif
        float contribution=sunlight*airDensity;
#if SHAFT_ADAPTIVE == 1 && defined(SCENE_SHADOWS) && LW_DIMENSION_BUDGET != 0
        // Replace one midpoint with two quarter samples when adjacent
        // visibility differs. Preserve the segment weight and cap work.
        if(extraSamples>=2 && tap>0 && abs(previousSunlight-sunlight)>0.55 && phase*day>0.12) {
            extraSamples-=2;
            vec4 a=clip-clipStep*0.25,b=clip+clipStep*0.25;
            float va=volumeShadowProjected(a.xyz/a.w*0.5+0.5);
            float vb=volumeShadowProjected(b.xyz/b.w*0.5+0.5);
            contribution=0.5*(va*exp(-max(altitude-deltaHeight*0.25-63.0,0.0)*0.019)
                +vb*exp(-max(altitude+deltaHeight*0.25-63.0,0.0)*0.019));
        }
#endif
        density+=contribution;
        previousSunlight=sunlight;
        float nextHeight=altitude+deltaHeight;
        // Recurrence is exact within the exponential branch. Reset at
        // the piecewise altitude boundary, including downward rays.
        airDensity=nextHeight<=63.0 ? 1.0 : (altitude>=63.0 ? airDensity*heightDecay : exp(-(nextHeight-63.0)*0.019));
        altitude=nextHeight;
    }
    return scene + celestialIrradiance(sun) * (density * stepSize * phase * day * (0.008 / 3.1));
}
