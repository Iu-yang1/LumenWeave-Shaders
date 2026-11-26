#ifndef LW_CELESTIAL_SKY
#define LW_CELESTIAL_SKY
uniform vec3 moonPosition;
uniform int moonPhase;

float skyHash(vec3 p) {
    p=fract(p*0.1031);
    p+=dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
}

float skyNoise(vec3 p) {
    vec3 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    float a=mix(skyHash(i),skyHash(i+vec3(1,0,0)),f.x);
    float b=mix(skyHash(i+vec3(0,1,0)),skyHash(i+vec3(1,1,0)),f.x);
    float c=mix(skyHash(i+vec3(0,0,1)),skyHash(i+vec3(1,0,1)),f.x);
    float d=mix(skyHash(i+vec3(0,1,1)),skyHash(i+vec3(1,1,1)),f.x);
    return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
}

// Direction-space procedural sky: no UV seam, time noise or camera translation.
vec3 endSkyDetail(vec3 direction) {
    vec3 p=direction*5.0;
    float n=0.62*skyNoise(p)+0.26*skyNoise(p*2.31+vec3(9,3,5))
        +0.12*skyNoise(p*5.13+vec3(3,12,7));
    vec3 axis=normalize(vec3(0.34,0.71,0.61));
    float latitude=abs(dot(direction,axis)+0.23*(n-0.5));
    float band=1.0-smoothstep(0.08,0.55,latitude);
    float wisps=smoothstep(0.32,0.80,n)*band;
    float ridge=pow(wisps,2.0);
    vec3 color=vec3(0.008,0.0025,0.023)*wisps
        +vec3(0.031,0.008,0.047)*ridge;
    // A cube-face directional lattice places stars ON the sky, rather than
    // randomly inside 3D cells that rarely intersect the unit sphere.
    vec3 a=abs(direction);
    vec2 uv; float face;
    if(a.x>=a.y && a.x>=a.z) {uv=direction.yz/a.x; face=direction.x>0.0?0.0:1.0;}
    else if(a.y>=a.z) {uv=direction.xz/a.y;face=direction.y>0.0?2.0:3.0;}
    else {uv=direction.xy/a.z;face=direction.z>0.0?4.0:5.0;}
    vec2 q=(uv*0.5+0.5)*96.0;
    vec3 cell=vec3(floor(q),face);
    float seed=skyHash(cell);
    vec2 center=mix(vec2(0.22),vec2(0.78),
        vec2(skyHash(cell+vec3(3,0,7)),skyHash(cell+vec3(0,7,2))));
    float radius=mix(0.035,0.095,skyHash(cell+vec3(5,2,1)));
    float footprint=clamp(length(fwidth(q)),0.008,0.15);
    float star=(1.0-smoothstep(radius,radius+footprint,length(fract(q)-center)))
        *step(0.955,seed)*(1.0-smoothstep(0.10,0.15,footprint));
    float intensity=mix(0.12,0.85,pow(skyHash(cell+vec3(8,3,2)),3.0));
    return color+star*intensity*mix(vec3(0.63,0.72,1.0),vec3(0.91,0.72,0.96),seed);
}

vec3 celestialSkyGlow(vec3 direction,vec3 sun) {
    float alignment=clamp(dot(direction,sun),-1.0,1.0);
    float edge=max(fwidth(alignment),0.000001);
    float disc=smoothstep(0.99972-edge,0.99972+edge,alignment);
    float theta=max(1.0-alignment,0.0);
    float corona=0.80*exp(-theta*170.0)+0.25*exp(-theta*18.0);
    float sunlight=smoothstep(-0.035,0.035,sun.y);
    vec3 color=(disc*11.0+corona)*sunTint(sun)*sunlight;
    vec3 moon=normalize(worldDirection(moonPosition));
    float lunarAngle=max(1.0-clamp(dot(direction,moon),-1.0,1.0),0.0);
    float moonHalo=0.12*exp(-lunarAngle*160.0)+0.035*exp(-lunarAngle*20.0);
    float phase=0.5+0.5*cos(float(moonPhase)*LW_PI*0.25);
    color+=vec3(0.53,0.68,1.0)*moonHalo*phase*smoothstep(-0.035,0.08,moon.y)*(1.0-daylight(sun));
    return color*(1.0-rainStrength)*(1.0-rainStrength*0.65);
}
#endif
