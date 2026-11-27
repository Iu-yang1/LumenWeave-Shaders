uniform float frameTimeCounter;
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

#include "/lib/atmosphere/cloud_noise.glsl"
#ifdef LW_CLOUD_CACHE_ACTIVE
#include "/lib/atmosphere/cloud_cache.glsl"
uniform sampler2D lwCloudShape;
#endif
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

#ifdef LW_CLOUD_CACHE_ACTIVE
vec2 cloudShapeAt(vec2 windPosition) {
    vec2 grid=windPosition/3.0;
    ivec2 cell=ivec2(floor(grid));
    ivec2 origin=cloudCacheOrigin();
    if(any(lessThan(cell,origin)) || any(greaterThanEqual(cell+1,origin+ivec2(512)))) {
        vec2 uv=windPosition*0.017;
        return vec2(0.65*cloudNoise(uv)+0.25*cloudNoise(uv*2.07),0.10*cloudNoise(uv*5.0));
    }
    ivec2 p=cloudWrap(cell);
    vec2 f=fract(grid);
    // Ordinary samples use one hardware bilinear lookup. At the torus seam
    // manually interpolate the four donors, avoiding the metadata column.
    if(all(lessThan(p,ivec2(511)))) {
        return textureLod(lwCloudShape,(vec2(p)+f+0.5)/vec2(513,512),0.0).rg;
    }
    vec2 a=texelFetch(lwCloudShape,p,0).rg;
    vec2 b=texelFetch(lwCloudShape,cloudWrap(cell+ivec2(1,0)),0).rg;
    vec2 c=texelFetch(lwCloudShape,cloudWrap(cell+ivec2(0,1)),0).rg;
    vec2 d=texelFetch(lwCloudShape,cloudWrap(cell+1),0).rg;
    return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
float cachedCloudDensity(vec3 position,float detail) {
    float h=(position.y-156.0)/18.0;
    float layer=smoothstep(0.0,0.24,h)*(1.0-smoothstep(0.55,1.0,h));
    if(layer<=0.0) return 0.0;
    vec2 shape=cloudShapeAt(cloudWindPosition(position.xz,frameTimeCounter));
    return layer*smoothstep(mix(0.48,0.34,rainStrength),0.78,shape.x+mix(0.05,shape.y,detail));
}
#endif
float cloudDensity(vec3 position,float detail) {
    if(position.y<=156.0 || position.y>=174.0) return 0.0;
    vec2 uv=cloudNoisePosition(position);
    return cloudDensityCoarse(position,detail,uv,cloudNoise(uv));
}
float cloudDensity(vec3 position) { return cloudDensity(position,1.0); }
float cloudSolarOpticalDepth(vec3 position,float detail) {
#if defined(LW_CLOUD_CACHE_ACTIVE) && CLOUD_OPTICAL_CACHE == 1
    // Current light model uses a single shifted density, not a full
    // light-ray integral. Cache its horizontal optical-density basis;
    // evaluate height profile and weather at the current sample.
    return 2.6*cachedCloudDensity(position,detail);
#else
    return 2.6*cloudDensity(position,detail);
#endif
}

vec4 cloudVolumeTransferBudget(vec3 origin,vec3 direction,vec3 sun,float maxDistance,float fallbackRate) {
    if (!hasSkylight) {
        return vec4(0.0,0.0,0.0,1.0);
    }
    // Intersect the actual cloud slab, including horizontal rays inside it.
    float start=0.0;
    float end=min(maxDistance,640.0);
    if(direction.y==0.0) {
        if(origin.y<=156.0 || origin.y>=174.0) return vec4(0.0,0.0,0.0,1.0);
    } else {
        vec2 distances=(vec2(156.0,174.0)-origin.y)/direction.y;
        start=max(min(distances.x,distances.y),0.0);
        end=min(end,max(distances.x,distances.y));
    }
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
#if MULTIRATE_VOLUME > 0 && LW_DIMENSION_BUDGET != 0
    // Distant, smoothly varying density needs fewer quadrature points.
    // Near/inside cloud layers keep the original budget.
    float farRate=smoothstep(64.0,192.0,start);
    float fraction=mix(1.0,MULTIRATE_VOLUME==2?0.50:0.75,farRate);
    steps=min(steps,max(min(4,CLOUD_STEPS),int(ceil(float(steps)*fraction))));
#endif
    // A failed spatial reconstruction still samples the current ray.
    // Only distant cloud layers use the lower fallback integration rate.
    if(fallbackRate<1.0 && start>=48.0)
        steps=min(steps,max(min(4,CLOUD_STEPS),int(ceil(float(steps)*fallbackRate))));
    float stepSize = span / float(steps);
    float day = daylight(sun);
    vec3 tint = sunTint(sun);
    float directWeight=(1.0-rainStrength)*(1.0-rainStrength);
    vec3 cloudAmbient=mix(vec3(0.41,0.48,0.58),vec3(0.34,0.38,0.43),rainStrength);
    vec3 solarTint=tint*(0.58*directWeight);
    float weatherAttenuation=1.0-rainStrength*0.28;
    float transmission = 1.0;
    vec3 scattering = vec3(0.0);
    float detail=1.0;
#if CLOUD_ADAPTIVE == 1 && LW_DIMENSION_BUDGET != 0
    // Fade the highest octave only when the ray or pixel footprint
    // undersamples its ~11.8-block lattice and the cloud is distant.
    float rayFootprint=length(direction.xz)*stepSize;
    float pixelFootprint=2.0*abs(gbufferProjectionInverse[1][1])*start/max(float(lwRasterSize(depthtex0).y),1.0);
    detail=1.0-smoothstep(128.0,400.0,start)*smoothstep(0.25,0.65,max(rayFootprint,pixelFootprint)*0.085);
#endif
    vec3 rayStep=direction*stepSize;
    float rayStepLength=stepSize; // direction is normalized by volumeRay
    vec3 point=origin+direction*(start+0.5*stepSize);
    float previousDensity=-1.0;
    float previousLight=1.0;
    int lastLightTap=-2;
    for(int tap=0;tap<steps;++tap,point+=rayStep) {
#ifdef LW_CLOUD_CACHE_ACTIVE
        // Interpolated density is approximate; do not apply the original
        // coarse-octave Lipschitz proof to this different representation.
        float density=cachedCloudDensity(point,detail);
#elif CLOUD_EMPTY_SKIP == 1 && CLOUD_NOISE_MODE == 1
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
            float light=0.0;
            // No solar shadow-density lookup when the direct term is exactly zero.
            if(directWeight>0.0) {
#if CLOUD_LIGHT_REUSE == 1 && LW_DIMENSION_BUDGET != 0
            // Reuse at most one adjacent light query where both the density
            // and spatial displacement are small. Never cross an empty gap.
            if(tap==lastLightTap+1 && abs(density-previousDensity)<0.025 &&
               rayStepLength<1.8 && start>80.0) {
                light=previousLight;
            } else {
                light=exp(-cloudSolarOpticalDepth(point+sun*6.0,detail));
                previousLight=light;
                previousDensity=density;
                lastLightTap=tap;
            }
#else
            light=exp(-cloudSolarOpticalDepth(point+sun*6.0,detail));
#endif
            }
            vec3 dayCloud=cloudAmbient+solarTint*light;
            radiance=mix(radiance,dayCloud,day);
        }
        radiance *= weatherAttenuation;
        scattering += radiance * transmission * opacity;
        transmission *= 1.0 - opacity;
        if (transmission < 0.015) {
            break;
        }
    }
    float coverage=1.0-smoothstep(410.0,630.0,start);
    return vec4(scattering*coverage,mix(1.0,transmission,coverage));
}

vec4 cloudVolumeTransfer(vec3 origin,vec3 direction,vec3 sun,float maxDistance){
    return cloudVolumeTransferBudget(origin,direction,sun,maxDistance,1.0);
}
vec3 applyCloudVolume(vec3 scene,vec3 origin,vec3 direction,vec3 sun,float maxDistance) {
    vec4 transfer=cloudVolumeTransfer(origin,direction,sun,maxDistance);
    return scene*transfer.a+transfer.rgb;
}

vec3 applyLightShaftsBudget(vec3 scene,vec3 origin,vec3 direction,vec3 sun,float maxDistance,float fallbackRate) {
    if (!hasSkylight) {
        return scene;
    }
    float day = smoothstep(0.0, 0.2, sun.y) * (1.0 - rainStrength);
    float cosine = max(dot(direction, sun), 0.0);
    float cosine2=cosine*cosine;
    float phase = 0.025 + 0.975 * cosine2*cosine2*cosine2;
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
    // Strong rays retain the original base taps. Refine only when the
    // user's cap still has spare comparisons.
    extraSamples=max(0,SHAFT_STEPS-steps);
#endif
#if MULTIRATE_VOLUME > 0 && LW_DIMENSION_BUDGET != 0
    // Weak forward-scattering term: reduce quadrature while still sampling
    // current shadows. Strong shafts and near occluders remain unchanged.
    if(span>18.0 && phase*day<0.055){
        steps=max(min(2,SHAFT_STEPS),steps-(MULTIRATE_VOLUME==2?2:1));
        extraSamples=0;
    }
#endif
    if(fallbackRate<1.0 && span>=12.0 && phase*day<0.12){
        steps=min(steps,max(min(2,SHAFT_STEPS),int(ceil(float(steps)*fallbackRate))));
        extraSamples=0;
    }
    float stepSize=span/float(steps);
    float density=0.0;
    vec3 rayStep=direction*stepSize;
    vec3 offset=0.5*rayStep;
#ifdef SCENE_SHADOWS
    vec4 clipStart=shadowProjection*(shadowModelView*vec4(offset,1.0));
    vec4 clipStep=shadowProjection*(shadowModelView*vec4(rayStep,0.0));
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

vec3 applyLightShafts(vec3 scene,vec3 origin,vec3 direction,vec3 sun,float maxDistance){return applyLightShaftsBudget(scene,origin,direction,sun,maxDistance,1.0);}
