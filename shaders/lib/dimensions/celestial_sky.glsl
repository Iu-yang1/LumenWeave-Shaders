#ifndef LW_CELESTIAL_SKY
#define LW_CELESTIAL_SKY
uniform vec3 moonPosition;
uniform int moonPhase;

#include "/lib/dimensions/end_nebula.glsl"

// Direction-space procedural sky: no UV seam, time noise or camera translation.
vec3 endSkyDetail(vec3 direction,float pixelFootprint) {
    vec3 color=endNebula(direction);
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
    // Most cells have no star. Avoid their extra hashes and distance work.
    if(seed<0.955) return color;
    vec2 center=mix(vec2(0.22),vec2(0.78),
        vec2(skyHash(cell+vec3(3,0,7)),skyHash(cell+vec3(0,7,2))));
    float radius=mix(0.035,0.095,skyHash(cell+vec3(5,2,1)));
    float footprint=clamp(pixelFootprint,0.008,0.15);
    float star=(1.0-smoothstep(radius,radius+footprint,length(fract(q)-center)))
        *(1.0-smoothstep(0.10,0.15,footprint));
    float intensity=mix(0.12,0.85,pow(skyHash(cell+vec3(8,3,2)),3.0));
    return color+star*intensity*mix(vec3(0.63,0.72,1.0),vec3(0.91,0.72,0.96),seed);
}

vec3 endSkyDetail(vec3 direction) {
    // Only legacy geometry sky callers use derivatives; the authoritative
    // deferred sky supplies a uniform screen footprint.
    return endSkyDetail(direction,96.0*length(fwidth(direction)));
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
