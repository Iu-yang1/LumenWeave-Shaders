const float shadowDistance = SHADOW_RANGE;
const float shadowDistanceRenderMul = 1.0;
#if SHADOW_MAP != 0
const int shadowMapResolution = SHADOW_MAP;
#elif defined(DEFERRED_LIGHTING)
const int shadowMapResolution = 1024;
#else
const int shadowMapResolution = 512;
#endif
#ifdef SOFT_SHADOWS
const bool shadowHardwareFiltering = false;
uniform sampler2D shadowtex0;
#else
const bool shadowHardwareFiltering = true;
uniform sampler2DShadow shadowtex0;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;

#ifdef SOFT_SHADOWS
// Orthographic shadow projection: transform the receiver normal into light
// view space and solve n.x*dx+n.y*dy+n.z*dz=0 in normalized shadow UVZ.
// Clamp near grazing incidence, where the plane becomes ill-conditioned.
vec2 receiverDepthGradient(vec3 normal) {
    vec3 n=mat3(shadowModelView)*normal;
    float nz=(n.z<0.0 ? -1.0 : 1.0)*max(abs(n.z),0.12);
    vec2 gradient=-(n.xy/nz)*shadowProjection[2][2]/vec2(shadowProjection[0][0],shadowProjection[1][1]);
    return clamp(gradient,vec2(-8.0),vec2(8.0));
}

float receiverDepthAt(vec3 receiver,vec2 gradient,ivec2 pixel,ivec2 resolution) {
    vec2 offset=(vec2(pixel)+0.5)-receiver.xy*vec2(resolution);
    return receiver.z+dot(gradient/vec2(resolution),offset);
}

float compareShadowTexel(vec3 receiver,vec2 gradient,ivec2 pixel,ivec2 resolution) {
    pixel=clamp(pixel,ivec2(0),resolution-1);
    return step(receiverDepthAt(receiver,gradient,pixel,resolution),texelFetch(shadowtex0,pixel,0).r);
}

float filteredReceiverShadow(vec2 uv,vec3 receiver,vec2 gradient,ivec2 resolution) {
    vec2 position=uv*vec2(resolution)-0.5;
    ivec2 base=ivec2(floor(position));
    vec2 fraction=fract(position);
    float ll=compareShadowTexel(receiver,gradient,base,resolution);
    float lr=compareShadowTexel(receiver,gradient,base+ivec2(1,0),resolution);
    float ul=compareShadowTexel(receiver,gradient,base+ivec2(0,1),resolution);
    float ur=compareShadowTexel(receiver,gradient,base+ivec2(1,1),resolution);
    return mix(mix(ll,lr,fraction.x),mix(ul,ur,fraction.x),fraction.y);
}

// Volume samples have no receiver surface; retain the ordinary depth comparison.
float filteredShadow(vec2 uv,float receiverDepth,ivec2 resolution) {
    return filteredReceiverShadow(uv,vec3(uv,receiverDepth),vec2(0.0),resolution);
}

float softShadow(vec3 receiver,vec2 gradient,float viewDistance) {
    const vec2 taps[8]=vec2[8](
        vec2(-0.62,-0.62),vec2(-0.16,-0.38),
        vec2(0.62,-0.62),vec2(0.38,-0.16),
        vec2(0.62,0.62),vec2(0.16,0.38),
        vec2(-0.62,0.62),vec2(-0.38,0.16)
    );
    ivec2 resolution = textureSize(shadowtex0, 0);
    vec2 texel = 1.0 / vec2(resolution);
    float sum = 0.0;
    float count = 0.0;
    float center=filteredReceiverShadow(receiver.xy,receiver,gradient,resolution);
    int blockerTaps=SHADOW_FILTER_TAPS;
    int filterTaps=SHADOW_FILTER_TAPS;
#ifdef ADAPTIVE_SHADOWS
    if(viewDistance>28.0) blockerTaps=min(4,SHADOW_FILTER_TAPS);
    if(viewDistance>48.0) filterTaps=min(4,SHADOW_FILTER_TAPS);
#endif
    int blockerStride=blockerTaps==8 ? 1 : 2;
    for (int index = 0; index < SHADOW_FILTER_TAPS; ++index) {
        if(index>=blockerTaps) break;
        int tap=index*blockerStride;
        ivec2 p=clamp(ivec2((receiver.xy+taps[tap]*texel*3.5)*vec2(resolution)),ivec2(0),resolution-1);
        float depth=texelFetch(shadowtex0,p,0).r;
        float plane=receiverDepthAt(receiver,gradient,p,resolution);
        if(depth<plane) {
            sum+=plane-depth;
            count += 1.0;
        }
    }
    if (count == 0.0) {
        return center;
    }
    float separation = (sum / count) * (2.0 / abs(shadowProjection[2][2]));
    float radius = clamp(separation * 0.018 / (2.0 * shadowDistance * texel.x), 1.0, 8.0);
    float samples = center;
#ifdef ADAPTIVE_SHADOWS
    if(viewDistance>28.0 && radius<=1.5) filterTaps=min(4,filterTaps);
    // Distant, uniformly blocked probes with a narrow penumbra need no
    // extra filtering. This is an approximation only on far surfaces.
    if(viewDistance>48.0 && count==float(blockerTaps) && center==0.0 && radius<=1.5) return 0.0;
#endif
    int filterStride=filterTaps==8 ? 1 : 2;
    for (int index = 0; index < SHADOW_FILTER_TAPS; ++index) {
        if(index>=filterTaps) break;
        int tap=index*filterStride;
        samples += filteredReceiverShadow(receiver.xy+taps[tap]*texel*radius,receiver,gradient,resolution);
    }
    return samples / float(filterTaps + 1);
}
#endif

float sceneShadow(vec3 position, vec3 normal, vec3 light, bool detailed) {
    vec3 shadowLight = normalize(worldDirection(shadowLightPosition));
    if (dot(shadowLight, light) < 0.9 || dot(normal, light) <= 0.0) {
        return 1.0;
    }
    float grazing = 1.0 - max(dot(normal, light), 0.0);
    float worldTexel = 2.0 * shadowDistance / float(shadowMapResolution);
    vec3 offset = normal * clamp(worldTexel * mix(0.22, 0.60, grazing), 0.012, 0.095);
    vec4 clip = shadowProjection * shadowModelView * vec4(position + offset, 1.0);
    vec3 samplePosition = clip.xyz / clip.w * 0.5 + 0.5;
    vec2 edge = abs(samplePosition.xy - 0.5);
    float range = max(edge.x, edge.y);
    if (range >= 0.49 || samplePosition.z <= 0.0 || samplePosition.z >= 1.0) {
        return 1.0;
    }
    samplePosition.z -= clamp(0.16 / float(shadowMapResolution), 0.00004, 0.00020);
#ifdef SOFT_SHADOWS
    vec2 gradient=receiverDepthGradient(normal);
    float visibility = detailed ? softShadow(samplePosition,gradient,length(position))
        : filteredReceiverShadow(samplePosition.xy,samplePosition,gradient,textureSize(shadowtex0,0));
#else
    float visibility = texture(shadowtex0, samplePosition);
#endif
    return mix(visibility, 1.0, smoothstep(0.39, 0.49, range));
}

float sceneShadow(vec3 position, vec3 normal, vec3 light) {
    return sceneShadow(position,normal,light,true);
}

float volumeShadow(vec3 position) {
    vec4 clip = shadowProjection * shadowModelView * vec4(position, 1.0);
    vec3 receiver = clip.xyz / clip.w * 0.5 + 0.5;
    vec2 edge = abs(receiver.xy - 0.5);
    float range = max(edge.x, edge.y);
    if (range >= 0.49 || receiver.z <= 0.0 || receiver.z >= 1.0) {
        return 1.0;
    }
    receiver.z -= clamp(0.16 / float(shadowMapResolution), 0.00004, 0.00020);
#ifdef SOFT_SHADOWS
    float visibility = filteredShadow(receiver.xy, receiver.z, textureSize(shadowtex0, 0));
#else
    float visibility = texture(shadowtex0, receiver);
#endif
    return mix(visibility, 1.0, smoothstep(0.39, 0.49, range));
}
