#ifndef LW_RAIN_RIPPLES
#define LW_RAIN_RIPPLES
#if RAIN_RIPPLES > 0
vec2 rainRippleSlope(vec2 position,float time,float footprint) {
    if(footprint>=0.35) return vec2(0.0);
    vec2 p=position*2.5, cell=floor(p), local=fract(p);
    vec2 result=vec2(0.0);
    for(int y=-1;y<=1;++y) for(int x=-1;x<=1;++x) {
#if RAIN_RIPPLES == 1
        if(abs(x)+abs(y)>1) continue;
#endif
        vec2 offset=vec2(x,y);
        vec3 hash=fract(vec3((cell+offset).xyx)*vec3(0.1031,0.1030,0.0973));
        hash+=dot(hash,hash.yzx+33.33);
        vec2 h=fract((hash.xx+hash.yz)*hash.zy);
        vec2 delta=local-offset-h;
        float d=length(delta), age=fract(time*1.25+h.x);
        float ring=d-age*0.85;
        float envelope=smoothstep(0.0,0.12,age)*(1.0-smoothstep(0.60,1.0,age))*(1.0-smoothstep(0.02,0.16,abs(ring)));
        if(envelope>0.0) result+=delta/max(d,0.001)*sin(ring*35.0)*envelope;
    }
    return result*0.075*(1.0-smoothstep(0.06,0.35,footprint));
}
#endif

#endif
