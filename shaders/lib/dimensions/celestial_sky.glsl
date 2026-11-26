#ifndef LW_CELESTIAL_SKY
#define LW_CELESTIAL_SKY
uniform vec3 moonPosition;

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
    vec3 p=direction*4.0;
    float n=0.70*skyNoise(p)+0.30*skyNoise(p*2.31+vec3(9.0,3.0,5.0));
#ifndef LITE_LIGHTING
    n=0.82*n+0.18*skyNoise(p*5.13+vec3(3.0,12.0,7.0));
#endif
    float band=1.0-smoothstep(0.04,0.55,abs(dot(direction,normalize(vec3(0.34,0.71,0.61)))+0.16*(n-0.5)));
    float cloud=smoothstep(0.34,0.78,n)*band;
    vec3 color=mix(vec3(0.028,0.012,0.073),vec3(0.15,0.055,0.24),cloud)*cloud;
    // Analytic anti-aliased star cores; disable at subpixel density.
    vec3 q=direction*92.0;
    vec3 cell=floor(q);
    float seed=skyHash(cell);
    vec3 center=vec3(skyHash(cell+vec3(3,0,0)),skyHash(cell+vec3(0,7,0)),skyHash(cell+vec3(0,0,11)));
    center=mix(vec3(0.24),vec3(0.76),center);
    float distanceToStar=length(fract(q)-center);
    float footprint=clamp(length(fwidth(q)),0.012,0.24);
    float star=(1.0-smoothstep(0.038,0.038+footprint,distanceToStar))
        *step(0.975,seed)*(1.0-smoothstep(0.10,0.24,footprint));
    return color+star*mix(vec3(0.45,0.56,0.92),vec3(0.85,0.58,0.95),skyHash(cell+vec3(7,4,1)))*1.25;
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
    color+=vec3(0.53,0.68,1.0)*moonHalo*smoothstep(-0.035,0.08,moon.y)*(1.0-daylight(sun));
    return color*(1.0-rainStrength)*(1.0-rainStrength*0.65);
}
#endif
