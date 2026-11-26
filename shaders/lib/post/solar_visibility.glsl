#include "/lib/coordinates/raster_grid.glsl"
// Shared by the meter and final vertex stage; depth occlusion is current-frame.
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform bool hasSkylight;
uniform int isEyeInWater;
uniform float lwRain;
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif
#ifdef LW_CELESTIAL_VOLUME_SPATIAL
uniform sampler2D colortex9;
#ifdef LW_SCENE_TAAU
#include "/lib/temporal/scene_grid.glsl"
#endif
#endif
vec4 solarVisibility(sampler2D source){
#if defined(LW_DIMENSION_NETHER) || defined(LW_DIMENSION_END)
    return vec4(0.0);
#else
    vec3 dir=normalize(sunPosition);
    float elevation=(mat3(gbufferModelViewInverse)*dir).y;
    if(!hasSkylight || isEyeInWater!=0 || dir.z>=-0.02 || elevation<=0.0) return vec4(0.0);
    vec4 p=gbufferProjection*vec4(dir,0.0);
    if(p.w<=0.0) return vec4(0.0);
    vec2 uv=p.xy/p.w*0.5+0.5;
    vec2 pixel=1.0/vec2(lwRasterSize(depthtex0));
    // The rendered disk uses cos(theta)=0.99972. Scale taps with FOV.
    vec2 radius=max(pixel*1.5,0.5*abs(vec2(gbufferProjection[0][0],gbufferProjection[1][1]))*0.02367/max(-dir.z,0.02));
    if(any(lessThan(uv,-radius))||any(greaterThan(uv,1.0+radius))) return vec4(0.0);
    float visible=0.0, light=0.0;
    for(int y=-1;y<=1;++y)for(int x=-1;x<=1;++x) {
        vec2 sampleUv=uv+vec2(x,y)*radius*0.65;
        if(any(lessThan(sampleUv,vec2(0.0)))||any(greaterThan(sampleUv,vec2(1.0)))) continue;
        float openSky=step(0.999999,lwPostDepth(depthtex0,sampleUv));
#ifdef DISTANT_HORIZONS
        openSky*=step(0.999999,lwPostDepth(dhDepthTex0,sampleUv));
#endif
        visible+=openSky;
#ifdef LW_CELESTIAL_VOLUME_SPATIAL
        vec2 cloudUv=sampleUv;
#ifdef LW_GEOMETRY_TAAU
        cloudUv=lwRasterStorageUv(colortex9,sampleUv);
#elif defined(LW_SCENE_TAAU)
        ivec2 fullSize=textureSize(colortex9,0);
        ivec2 activeSize=lwSceneRenderSize(fullSize);
        cloudUv=clamp(sampleUv*vec2(activeSize),vec2(0.5),vec2(activeSize)-0.5)/vec2(fullSize);
#endif
        light+=openSky*clamp(textureLod(colortex9,cloudUv,0.0).a,0.0,1.0);
#else
        light+=openSky*smoothstep(0.9,4.0,dot(textureLod(source,sampleUv,0.0).rgb,vec3(0.2126,0.7152,0.0722)));
#endif
    }
    float intensity=light/9.0*pow(1.0-lwRain,2.0)*smoothstep(0.0,0.08,elevation);
    vec2 edge=min(uv,1.0-uv);
    intensity*=smoothstep(-max(radius.x,radius.y),0.025,min(edge.x,edge.y));
    return vec4(uv,intensity,elevation);
#endif
}
