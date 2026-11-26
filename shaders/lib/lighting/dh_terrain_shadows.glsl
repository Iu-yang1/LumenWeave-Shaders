#ifndef LW_DH_DEPTH0_DECLARED
uniform sampler2D dhDepthTex0;
#endif
uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;

float dhShadowMapCoverage(vec3 position) {
    vec4 clip=shadowProjection*shadowModelView*vec4(position,1.0);
    vec3 p=clip.xyz/clip.w*0.5+0.5;
    if(p.z<=0.0 || p.z>=1.0) return 0.0;
    vec2 edge=abs(p.xy-0.5);
    return 1.0-smoothstep(0.39,0.49,max(edge.x,edge.y));
}

// Far terrain visibility outside the near shadow frustum. Only screen-visible
// occluders can be observed, so confidence fades at screen/depth discontinuities.
float distantTerrainVisibility(vec3 position,vec3 normalView,vec3 lightView) {
    float depth=-position.z;
    float pixelFootprint=2.0*depth/(max(float(lwRasterSize(dhDepthTex0).y),1.0)*max(abs(dhProjection[1][1]),0.01));
    float bias=clamp(pixelFootprint*1.4,0.65,5.0);
    vec3 origin=position+normalView*bias;
    float travel=max(2.5,bias*1.6);
    float maxTravel=clamp(depth*0.22,48.0,384.0);
    float stepRatio=pow((maxTravel+4.0)/(travel+4.0),1.0/float(max(DH_SHADOW_STEPS-1,1)));
    float occlusion=0.0;
    for(int tap=0;tap<DH_SHADOW_STEPS;++tap) {
        if(travel>maxTravel) break;
        vec3 ray=origin+lightView*travel;
        if(ray.z>=-0.12) break;
        vec4 clip=dhProjection*vec4(ray,1.0);
        if(clip.w<=0.0) break;
        vec2 uv=clip.xy/clip.w*0.5+0.5;
#ifdef LW_GEOMETRY_TAAU
        uv+=jitterOffset(frameCounter);
#endif
#ifdef LW_TAA_ACTIVE
        uv+=jitterOffset(frameCounter);
#endif
        vec2 edge=min(uv,1.0-uv);
        if(min(edge.x,edge.y)<=0.0) break;
        ivec2 pixel=depthPixelAtUv(dhDepthTex0,uv);
        float sampleDepth=texelFetch(dhDepthTex0,pixel,0).r;
        if(sampleDepth<1.0) {
            vec3 samplePosition=reconstructProjection(depthPixelUv(dhDepthTex0,pixel),sampleDepth,dhProjectionInverse,true);
            float delta=samplePosition.z-ray.z;
            float tolerance=max(bias*2.5,travel*0.045+pixelFootprint*1.5);
            if(delta>0.0 && length(samplePosition-position)>bias*2.0 && delta<tolerance) {
                float confidence=smoothstep(0.0,0.06,min(edge.x,edge.y));
                confidence*=smoothstep(0.0,max(0.1,bias*0.4),delta);
                confidence*=1.0-smoothstep(tolerance*0.6,tolerance,delta);
                confidence*=1.0-smoothstep(maxTravel*0.65,maxTravel,travel);
                occlusion=max(occlusion,confidence);
            }
        }
        if(occlusion>0.98) break;
        travel=(travel+4.0)*stepRatio-4.0;
    }
    return 1.0-occlusion*0.80;
}

vec3 shadeDistantTerrain(vec3 albedo,vec4 geometry,vec3 viewPosition) {
    vec3 normal=decodeNormal(geometry.xy);
    vec3 sun=sunDirection();
    vec3 light=sun.y>=0.0?sun:-sun;
    float visibility=smoothstep(0.0,0.18,abs(sun.y))*mix(1.0,0.19,rainStrength);
    float direct=max(dot(normal,light),0.0)*smoothstep(0.56,1.0,geometry.w)*visibility;
    float shadow=1.0;
    if(hasSkylight && direct>0.0) {
        vec3 position=(gbufferModelViewInverse*vec4(viewPosition,1.0)).xyz;
        float coverage=dhShadowMapCoverage(position);
        if(coverage>0.0) shadow=sceneShadow(position,normal,light);
        if(coverage<0.98 && direct>0.015) {
            mat3 toView=transpose(mat3(gbufferModelViewInverse));
            float farShadow=distantTerrainVisibility(viewPosition,toView*normal,toView*light);
            shadow*=mix(farShadow,1.0,coverage);
        }
    }
    return albedo*(ambientIrradiance(geometry.zw,normal.y,sun)+celestialIrradiance(sun)*direct*shadow/LW_PI);
}
