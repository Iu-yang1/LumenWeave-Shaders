#ifndef LW_END_NEBULA
#define LW_END_NEBULA
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


float proceduralEndWisps(vec3 direction) {
    vec3 p=direction*5.0;
    float n=0.62*skyNoise(p)+0.26*skyNoise(p*2.31+vec3(9,3,5))
        +0.12*skyNoise(p*5.13+vec3(3,12,7));
    vec3 axis=normalize(vec3(0.34,0.71,0.61));
    float latitude=abs(dot(direction,axis)+0.23*(n-0.5));
    float band=1.0-smoothstep(0.08,0.55,latitude);
    return smoothstep(0.32,0.80,n)*band;
}

#if END_NEBULA_ASSET == 1
uniform sampler2D lwEndWisps;
vec2 endOctahedralUV(vec3 direction) {
    vec3 n=direction/(abs(direction.x)+abs(direction.y)+abs(direction.z));
    vec2 p=n.xy;
    if(n.z<0.0) p=(1.0-abs(p.yx))*mix(vec2(-1.0),vec2(1.0),greaterThanEqual(p,vec2(0.0)));
    return ((p*0.5+0.5)*255.0+0.5)/256.0;
}
#endif
vec3 endNebula(vec3 direction) {
#if END_NEBULA_ASSET == 1
    float wisps=textureLod(lwEndWisps,endOctahedralUV(direction),0.0).r;
#else
    float wisps=proceduralEndWisps(direction);
#endif
    float ridge=wisps*wisps;
    return vec3(0.008,0.0025,0.023)*wisps
        +vec3(0.031,0.008,0.047)*ridge;
}
#endif
