#version 330 compatibility

#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
#ifdef LW_TAA_DIRECT
vec4 sceneColor;
#else
layout(location = 0) out vec4 sceneColor;
#endif

#ifdef LW_TAA_ACTIVE
#if defined(DEFERRED_LIGHTING)

#include "/lib/coordinates/reconstruct.glsl"
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#endif
#include "/lib/materials/geometry_buffer.glsl"

/*
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#ifdef LW_TAA_DIRECT
/* RENDERTARGETS: 4,5 */
layout(location=0) out vec4 colorHistory;
layout(location=1) out vec4 normalHistory;
#else
/* RENDERTARGETS: 0,4,5 */
layout(location=1) out vec4 colorHistory;
layout(location=2) out vec4 normalHistory;
#endif
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferModelViewInverse;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;
#endif

#include "/lib/temporal/reproject.glsl"
#ifdef LW_SCENE_TAAU
#include "/lib/temporal/scene_grid.glsl"
#endif

vec3 clipHistory(ivec2 pixel, vec3 history) {
    ivec2 size=textureSize(colortex0,0);
    ivec2 limit=size-1;
#ifdef LW_GEOMETRY_TAAU
    limit=lwRasterSize(colortex0)-1;
#elif defined(LW_SCENE_TAAU)
    pixel=lwSceneNearest((vec2(pixel)+0.5)/vec2(size),size,frameCounter);
    limit=lwSceneRenderSize(size)-1;
#endif
    vec3 lower = texelFetch(colortex0, pixel, 0).rgb;
    vec3 upper = lower;
    for (int row = -1; row <= 1; ++row) {
        for (int column = -1; column <= 1; ++column) {
            if (row == 0 && column == 0) {
                continue;
            }
            ivec2 adjacent = clamp(pixel + ivec2(column, row), ivec2(0), limit);
            vec3 sampleColor = texelFetch(colortex0, adjacent, 0).rgb;
            lower = min(lower, sampleColor);
            upper = max(upper, sampleColor);
        }
    }
#if defined(LW_STABLE_DYNAMIC) || defined(LW_SCENE_TAAU) || defined(LW_GEOMETRY_TAAU)
    // A flat neighbourhood has zero spatial variance but may have nonzero
    // temporal sampling variance. A small HDR-relative envelope preserves
    // accumulation there while depth/normal ownership rejects disocclusions.
    vec3 extent = max((upper-lower)*0.15,max(abs((lower+upper)*0.5)*0.12,vec3(0.002)));
    return clamp(history,max(lower-extent,vec3(0.0)),upper+extent);
#else
    return clamp(history, lower, upper);
#endif
}

vec4 filteredHistory(vec2 uv, float expectedDepth, vec2 normal, bool water, bool distant, bool sky) {
    ivec2 size = textureSize(colortex4, 0);
    vec2 position = uv * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(position));
    vec2 fraction = fract(position);
    vec4 result = vec4(0.0);
    vec3 currentNormal = decodeNormal(normal);
    float normalThreshold = water ? 0.86 : mix(0.86, 0.25, smoothstep(32.0, 128.0, expectedDepth));
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 samplePixel = base + ivec2(column, row);
            if (any(lessThan(samplePixel, ivec2(0))) || any(greaterThanEqual(samplePixel, size))) {
                continue;
            }
            vec4 history = texelFetch(colortex4, samplePixel, 0);
            vec4 metadata = texelFetch(colortex5, samplePixel, 0);
#if defined(LW_STABLE_DYNAMIC) || defined(LW_SCENE_TAAU) || defined(LW_GEOMETRY_TAAU)
#ifdef LW_GEOMETRY_TAAU
            vec2 historySize=vec2(lwRasterExtent(size));
#elif defined(LW_SCENE_TAAU)
            vec2 historySize=vec2(lwSceneRenderSize(size));
#else
            vec2 historySize=vec2(size);
#endif
            // Width sign encodes the DH projection, height sign encodes sky.
            if (any(greaterThan(abs(abs(metadata.zw)-historySize),vec2(1.0))) ||
                    (metadata.w<0.0)!=sky || (metadata.z<0.0)!=distant) {
                continue;
            }
            if (!sky && ((history.a<0.0)!=water || !matchesHistoryDepth(abs(history.a),expectedDepth)
                    || dot(currentNormal,decodeNormal(metadata.xy))<normalThreshold)) {
                continue;
            }
#else
            if ((history.a < 0.0) != water || !matchesHistoryDepth(abs(history.a), expectedDepth)) {
                continue;
            }
            // Half-float stores common display dimensions exactly. Allow one pixel
            // for rounding odd widths above 2048; reject resized/stale history.
            if (any(greaterThan(abs(metadata.zw - vec2(size)), vec2(1.0)))
                    || dot(currentNormal, decodeNormal(metadata.xy)) < normalThreshold) {
                continue;
            }
#endif
            vec2 weights = mix(1.0 - fraction, fraction, vec2(column, row));
            float weight = weights.x * weights.y;
            result += vec4(history.rgb, 1.0) * weight;
        }
    }
    if (result.a > 0.0) {
        result.rgb /= result.a;
    }
    return result;
}

#ifdef SMOOTH_LIGHTING
uniform float frameTime;
#endif
vec3 temporalColor(vec3 current, vec3 viewPosition, vec2 normal, ivec2 pixel, mat4 previousProjection, bool water, bool distant) {
    vec2 previousUv;
    float expectedDepth;
    if (!reprojectStableTerrain(viewPosition, previousUv, expectedDepth, previousProjection)) {
        return current;
    }
    vec2 size = vec2(textureSize(colortex4, 0));
#if defined(LW_TEMPORAL_REUSE) && !defined(LW_DYNAMIC_JITTER) && !defined(LW_SCENE_TAAU) && !defined(LW_GEOMETRY_TAAU)
    if(!water && !distant && length((previousUv-texCoord)*size)<0.20) {
        vec4 history=texelFetch(colortex4,pixel,0);
        vec4 metadata=texelFetch(colortex5,pixel,0);
        if(matchesHistoryDepth(history.a,expectedDepth) &&
            all(lessThanEqual(abs(metadata.zw-size),vec2(1.0))) &&
            dot(decodeNormal(normal),decodeNormal(metadata.xy))>0.96 &&
            all(lessThanEqual(abs(history.rgb-current),vec3(0.001)+abs(current)*0.008))) {
            return mix(current,history.rgb,0.92);
        }
    }
#endif
#ifdef LW_GEOMETRY_TAAU
    // Native output history is not indexed by the reduced geometry pixel.
    // Only reuse the exact output pixel for stationary, matching geometry
    // and color. Disagreement still goes through bilateral history/clipping.
    if(!water && !distant && length((previousUv-texCoord)*size)<0.20) {
        ivec2 outputPixel=ivec2(gl_FragCoord.xy);
        vec4 history=texelFetch(colortex4,outputPixel,0);
        vec4 metadata=texelFetch(colortex5,outputPixel,0);
        if(metadata.z>0.0 && metadata.w>0.0 && history.a>0.0 &&
            all(lessThanEqual(abs(metadata.zw-vec2(lwRasterExtent(ivec2(size)))),vec2(1.0))) &&
            matchesHistoryDepth(history.a,expectedDepth) &&
            dot(decodeNormal(normal),decodeNormal(metadata.xy))>0.96 &&
            all(lessThanEqual(abs(history.rgb-current),vec3(0.001)+abs(current)*0.008)))
            return mix(current,history.rgb,0.92);
    }
#endif
    vec4 historySample = filteredHistory(previousUv, expectedDepth, normal, water, distant, false);
    if (historySample.a <= 0.0) {
        return current;
    }
    vec3 clipped = clipHistory(pixel, historySample.rgb);
    float motion = length((previousUv - texCoord) * size);
    float stationaryWeight = mix(0.92, 0.97, smoothstep(32.0, 128.0, -viewPosition.z));
    float weight = water ? mix(0.78, 0.55, smoothstep(2.0, 20.0, motion))
        : mix(stationaryWeight, 0.72, smoothstep(2.0, 20.0, motion));
    weight *= smoothstep(0.0, 0.5, historySample.a);
#ifdef LW_GEOMETRY_TAAU
    // Reactive water/bright changes cannot drag old lighting into a new sample.
    float change=length(current-historySample.rgb)/max(length(current)+length(historySample.rgb),0.02);
    weight*=mix(1.0,water?0.15:0.42,smoothstep(0.08,0.5,change));
#endif
    float materialId = texelFetch(colortex2, pixel, 0).y;
    if (materialId >= 10030.0 && materialId <= 10033.0) {
        // Nearby moving vegetation needs rejection; distant settled foliage benefits from history.
        weight *= mix(0.45,1.0,smoothstep(24.0,64.0,-viewPosition.z));
    }
    vec3 resolved=mix(current,clipped,weight);
#ifdef SMOOTH_LIGHTING
    // History passed depth/normal/reprojection checks. Limit changes to
    // illumination of matched terrain, without dragging old geometry or hue.
    if(!water && !distant && motion<1.0 && !(materialId>=10030.0 && materialId<=10033.0)) {
        const vec3 lumaWeights=vec3(0.2126,0.7152,0.0722);
        float now=max(dot(current,lumaWeights),0.002);
        float old=max(dot(historySample.rgb,lumaWeights),0.002);
        float colorMatch=1.0-smoothstep(0.20,0.65,length(current/now-historySample.rgb/old));
        float adapt=exp2(-clamp(frameTime,0.0,0.25)/(now>old?0.10:0.18));
        float ratio=clamp(mix(now,old,adapt)/now,0.2,5.0);
        resolved=mix(resolved,current*ratio,colorMatch*(1.0-smoothstep(0.1,1.0,motion))*smoothstep(0.02,0.12,abs(log2(old/now))));
    }
#endif
    return resolved;
}

bool temporalGeometry(ivec2 pixel, vec2 uv, out vec3 viewPosition, out vec2 normal,
        out mat4 previousProjection, out bool water) {
    float depth = texelFetch(depthtex0, pixel, 0).r;
    float opaqueDepth = texelFetch(depthtex1, pixel, 0).r;
    float terrainDepth = texelFetch(colortex2, pixel, 0).r;
    vec4 geometry = texelFetch(colortex1, pixel, 0);
    water = geometry.z == -1.0;
    normal = geometry.xy;
    previousProjection = gbufferPreviousProjection;
    if (depth < 1.0) {
#ifdef LW_STABLE_DYNAMIC
        int owner = sampleOwner(uv,depth,false);
        if (owner!=1 && owner!=2) {
            return false;
        }
        water = owner==2;
#endif
        if (!water && (abs(depth - terrainDepth) > 0.00000012 || abs(depth - opaqueDepth) > 0.00000012)) {
            return false;
        }
        viewPosition = reconstructViewPosition(uv, depth);
    } else {
#ifdef DISTANT_HORIZONS
        ivec2 dhPixel = depthPixelAtUv(dhDepthTex0,uv);
        float distantDepth = texelFetch(dhDepthTex0,dhPixel,0).r;
        float distantOpaqueDepth = depthAtUv(dhDepthTex1,uv);
#ifdef LW_STABLE_DYNAMIC
        int owner = sampleOwner(uv,distantDepth,true);
        if (owner!=3 && owner!=4) {
            return false;
        }
        water = owner==4;
#endif
        if (distantDepth >= 1.0 || (!water && abs(distantDepth - distantOpaqueDepth) > 0.00000012)) {
            return false;
        }
        vec2 distantUv = depthPixelUv(dhDepthTex0,dhPixel);
        viewPosition = reconstructProjection(distantUv,distantDepth,dhProjectionInverse,true);
        previousProjection = dhPreviousProjection;
#else
        return false;
#endif
    }
    return true;
}

vec3 stableSurfacePosition(vec3 samplePosition, vec2 stableUv, vec2 encodedNormal, mat4 projectionInverse) {
    return stableViewSurfacePosition(samplePosition,stableUv,
        transpose(mat3(gbufferModelViewInverse))*decodeNormal(encodedNormal),projectionInverse);
}

#if defined(LW_STABLE_DYNAMIC) || defined(LW_SCENE_TAAU) || defined(LW_GEOMETRY_TAAU)
bool skyAtUv(vec2 uv) {
    bool sky = depthAtUv(depthtex0,uv)>=1.0;
#ifdef DISTANT_HORIZONS
    sky = sky && depthAtUv(dhDepthTex0,uv)>=1.0;
#endif
    return sky;
}
vec3 temporalSky(vec3 current,vec2 uv,ivec2 pixel) {
    vec3 ray = normalize((gbufferProjectionInverse*vec4(uv*2.0-1.0,1.0,1.0)).xyz);
    vec3 previousRay = mat3(gbufferPreviousModelView)*mat3(gbufferModelViewInverse)*ray;
    vec4 previousClip = gbufferPreviousProjection*vec4(previousRay,0.0);
    if(previousClip.w<=0.0) return current;
    vec2 previousUv = previousClip.xy/previousClip.w*0.5+0.5;
    if(any(lessThanEqual(previousUv,vec2(0.0))) || any(greaterThanEqual(previousUv,vec2(1.0)))) return current;
    vec4 history = filteredHistory(previousUv,0.0,vec2(0.0),false,false,true);
    if(history.a<=0.0) return current;
    float motion=length((previousUv-uv)*vec2(textureSize(colortex4,0)));
    return mix(current,clipHistory(pixel,history.rgb),0.85*history.a*(1.0-smoothstep(2.0,24.0,motion)));
}
#endif

vec3 resolveCurrent(ivec2 pixel, vec2 stableUv, vec3 position, vec2 normal, bool water, bool distant) {
#ifdef LW_GEOMETRY_TAAU
    ivec2 lowSize=lwRasterSize(colortex0);
    vec2 coordinate=(stableUv+jitterOffset(frameCounter))*vec2(lowSize)-0.5;
    ivec2 base=ivec2(floor(coordinate));
    vec2 fraction=fract(coordinate);
    vec3 result=vec3(0.0);float weightSum=0.0;
    vec3 referenceNormal=decodeNormal(normal);
    for(int y=0;y<2;++y)for(int x=0;x<2;++x){
        ivec2 donor=clamp(base+ivec2(x,y),ivec2(0),lowSize-1);
        vec2 uv=(vec2(donor)+0.5)/vec2(lowSize);
        vec3 p;vec2 n;mat4 prev;bool donorWater;
        vec2 w=mix(1.0-fraction,fraction,vec2(x,y));float weight=w.x*w.y;
        if(weight<=0.00001) continue;
        if(all(equal(donor,pixel))) {
            result+=texelFetch(colortex0,donor,0).rgb*weight;
            weightSum+=weight;
            continue;
        }
        if(!temporalGeometry(donor,uv,p,n,prev,donorWater) || donorWater!=water ||
            (texelFetch(depthtex0,donor,0).r>=1.0)!=distant ||
            abs(p.z-position.z)>max(0.10,-position.z*0.035) ||
            dot(referenceNormal,decodeNormal(n))<(water?0.86:0.75)) continue;
        result+=texelFetch(colortex0,donor,0).rgb*weight;weightSum+=weight;
    }
    return weightSum>0.001?result/weightSum:texelFetch(colortex0,pixel,0).rgb;
#elif defined(LW_SCENE_TAAU)
    ivec2 fullSize=textureSize(depthtex0,0),lowSize=lwSceneRenderSize(fullSize);
    vec2 coord=lwSceneLowCoord(stableUv,fullSize,frameCounter);
    ivec2 base=ivec2(floor(coord));vec2 fraction=fract(coord);
    vec3 color=vec3(0.0);float total=0.0;
    vec3 referenceNormal=decodeNormal(normal);
    for(int y=0;y<2;++y)for(int x=0;x<2;++x) {
        ivec2 low=clamp(base+ivec2(x,y),ivec2(0),lowSize-1);
        ivec2 donor=lwSceneDonorPixel(low,fullSize,frameCounter);
        vec2 uv=(vec2(donor)+0.5)/vec2(fullSize);
        vec3 p;vec2 n;mat4 prev;bool donorWater;
        vec2 w=mix(1.0-fraction,fraction,vec2(x,y));float weight=w.x*w.y;
        if(weight<=0.00001) continue;
        if(!temporalGeometry(donor,uv,p,n,prev,donorWater) || donorWater!=water ||
           (texelFetch(depthtex0,donor,0).r>=1.0)!=distant ||
           abs(p.z-position.z)>max(0.08,-position.z*0.025) ||
           dot(referenceNormal,decodeNormal(n))<(water?0.86:0.75)) continue;
        color+=texelFetch(colortex0,low,0).rgb*weight;total+=weight;
    }
    // Keep a bounded nearest donor when the low grid contains no matching
    // sample. History is separately validated on full-resolution geometry.
    return total>0.001?color/total:texelFetch(colortex0,lwSceneNearest(stableUv,fullSize,frameCounter),0).rgb;
#elif !defined(LW_DYNAMIC_JITTER) || defined(LW_STABLE_DYNAMIC)
    // The advanced path shades on the stable pixel grid already. Applying
    // another spatial jitter shift to the combined HDR radiance moves the
    // lighting/fog field twice. Accumulate the raster coverage temporally
    // at this pixel instead. The simple raw-raster path still resamples.
    return texelFetch(colortex0, pixel, 0).rgb;
#else
    ivec2 size = textureSize(colortex0, 0);
    vec2 location = (stableUv + jitterOffset(frameCounter)) * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(location));
    vec2 fraction = fract(location);
    vec3 color = vec3(0.0);
    float sum = 0.0;
    vec3 referenceNormal = decodeNormal(normal);
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 neighbor = base + ivec2(column, row);
            if (any(lessThan(neighbor, ivec2(0))) || any(greaterThanEqual(neighbor, size))) {
                continue;
            }
            vec2 weight = mix(1.0 - fraction, fraction, vec2(column, row));
            float w = weight.x * weight.y;
            if (w <= 0.00001) continue;
            vec2 neighborUv = (vec2(neighbor) + 0.5) / vec2(size);
            vec3 samplePosition;
            vec2 sampleNormal;
            mat4 sampleProjection;
            bool sampleWater;
            if (!temporalGeometry(neighbor, neighborUv, samplePosition, sampleNormal, sampleProjection, sampleWater)
                    || sampleWater != water
                    || (texelFetch(depthtex0, neighbor, 0).r >= 1.0) != distant
                    || abs(samplePosition.z - position.z) > max(0.08, -position.z * 0.025)
                    || dot(referenceNormal, decodeNormal(sampleNormal)) < 0.60) {
                continue;
            }
            color += texelFetch(colortex0, neighbor, 0).rgb * w;
            sum += w;
        }
    }
    return sum > 0.0001 ? color / sum : texelFetch(colortex0, pixel, 0).rgb;
#endif
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(colortex0, 0);
    vec2 stableUv = (vec2(pixel) + 0.5) / vec2(size);
    vec2 geometryUv=stableUv;
#ifdef LW_GEOMETRY_TAAU
    ivec2 lowSize=lwRasterSize(colortex0);
    pixel=clamp(ivec2((stableUv+jitterOffset(frameCounter))*vec2(lowSize)),ivec2(0),lowSize-1);
    geometryUv=(vec2(pixel)+0.5)/vec2(lowSize);
    sceneColor=texelFetch(colortex0,pixel,0);
    vec2 historySize=vec2(lowSize);
#elif defined(LW_SCENE_TAAU)
    sceneColor=texelFetch(colortex0,lwSceneNearest(stableUv,size,frameCounter),0);
    vec2 historySize=vec2(lwSceneRenderSize(size));
#else
    sceneColor = texelFetch(colortex0, pixel, 0);
    vec2 historySize=vec2(size);
#endif
#ifdef LW_TAA_DIRECT
    // Untouched sky/entities still need display RGB, but zero metadata
    // rejects these samples from geometry history.
    colorHistory=vec4(sceneColor.rgb,0.0);
#else
    colorHistory = vec4(0.0);
#endif
    normalHistory = vec4(0.0);
    vec3 viewPosition;
    vec2 normal;
    mat4 previousProjection;
    bool water;
    if (!temporalGeometry(pixel, geometryUv, viewPosition, normal, previousProjection, water)) {
#if defined(LW_STABLE_DYNAMIC) || defined(LW_SCENE_TAAU) || defined(LW_GEOMETRY_TAAU)
        if (skyAtUv(geometryUv)) {
            sceneColor.rgb = temporalSky(sceneColor.rgb,stableUv,pixel);
            colorHistory = vec4(sceneColor.rgb,0.0);
            normalHistory = vec4(0.0,0.0,historySize.x,-historySize.y);
        }
#endif
        return;
    }

    bool distant = texelFetch(depthtex0, pixel, 0).r >= 1.0;
    mat4 projectionInverse = gbufferProjectionInverse;
#ifdef DISTANT_HORIZONS
    if (distant) {
        projectionInverse = dhProjectionInverse;
    }
#endif
    // With fixed raster sampling the original depth already belongs to the output ray.
#if defined(LW_DYNAMIC_JITTER) || defined(LW_GEOMETRY_TAAU)
    vec3 stablePosition = stableSurfacePosition(viewPosition, stableUv, normal, projectionInverse);
#else
    vec3 stablePosition = viewPosition;
#endif
    vec3 current = resolveCurrent(pixel, stableUv, stablePosition, normal, water, distant);
    sceneColor.rgb = temporalColor(current, stablePosition, normal, pixel, previousProjection, water, distant);
    colorHistory = vec4(sceneColor.rgb, water ? stablePosition.z : -stablePosition.z);
#if defined(LW_STABLE_DYNAMIC) || defined(LW_SCENE_TAAU) || defined(LW_GEOMETRY_TAAU)
    normalHistory = vec4(normal,distant ? -historySize.x : historySize.x,historySize.y);
#else
    normalHistory = vec4(normal, vec2(size));
#endif
}

#endif
#endif

#ifndef LW_TAA_ACTIVE
/* RENDERTARGETS: 0 */

void main() {
    sceneColor = texture(colortex0, texCoord);
}
#endif
