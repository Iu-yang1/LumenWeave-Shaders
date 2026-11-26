#ifndef LW_PHYSICAL_COMMON
#define LW_PHYSICAL_COMMON
const float ATMO_PI = 3.14159265359;
const float ATMO_GROUND = 6360.0;
const float ATMO_TOP = 6460.0;
const float ATMO_KM_PER_BLOCK = 0.04;
const float ATMO_MAX_DISTANCE = 120.0;
const vec3 ATMO_RAYLEIGH = vec3(0.005802, 0.013558, 0.033100);
const vec3 ATMO_OZONE = vec3(0.000650, 0.001881, 0.000085);
const float ATMO_GROUND_ALBEDO = 0.12;

float atmoRadius(float worldHeight) {
    return ATMO_GROUND + clamp((worldHeight - 63.0) * ATMO_KM_PER_BLOCK + 0.2, 0.02, 99.9);
}
float atmoAltitudeRadius(float v) {
    return mix(ATMO_GROUND+0.02,ATMO_TOP,v*v);
}
float atmoAltitudeUv(float radius) {
    return sqrt(clamp((radius-ATMO_GROUND-0.02)/(ATMO_TOP-ATMO_GROUND-0.02),0.0,1.0));
}
float atmoElevationMu(float v) {
    float x=2.0*v-1.0;
    return sign(x)*x*x;
}
float atmoElevationUv(float mu) {
    return 0.5+0.5*sign(mu)*sqrt(abs(mu));
}
float atmoSegmentCoordinate(float t) {
    // Densify quadrature towards both ends of a long ray.
    return t*t*(3.0-2.0*t);
}
float atmoHorizon(float radius) {
    return -sqrt(max(0.0, (radius - ATMO_GROUND) * (radius + ATMO_GROUND))) / radius;
}
vec3 atmoDirection(float mu, float phi) {
    float h = sqrt(max(0.0, 1.0 - mu*mu));
    return vec3(h*cos(phi), mu, h*sin(phi));
}
vec2 atmoBoundary(float radius, float mu) {
    float b = radius*mu;
    float disc = b*b - (radius-ATMO_GROUND)*(radius+ATMO_GROUND);
    if (mu < atmoHorizon(radius) && disc >= 0.0) {
        return vec2(max(0.0,-b-sqrt(disc)),1.0);
    }
    return vec2(max(0.0,-b+sqrt(max(0.0,b*b+(ATMO_TOP-radius)*(ATMO_TOP+radius)))),0.0);
}
void atmoMedium(float radius, out vec3 rs, out float ms, out vec3 extinction) {
    float h = max(radius-ATMO_GROUND,0.0);
    rs = ATMO_RAYLEIGH*exp(-h/8.0);
    float m = exp(-h/1.2);
    ms = 0.003996*m;
    extinction = rs + vec3(0.004440*m) + ATMO_OZONE*max(0.0,1.0-abs(h-25.0)/15.0);
}
vec3 atmoTransmittance(float radius,float mu) {
    vec2 boundary = atmoBoundary(radius,mu);
    if (boundary.y > 0.5) return vec3(0.0);
    vec3 tau = vec3(0.0);
    for(int i=0;i<64;++i) {
        float a=boundary.x*atmoSegmentCoordinate(float(i)/64.0);
        float b=boundary.x*atmoSegmentCoordinate(float(i+1)/64.0);
        float dt=b-a;
        float t=(a+b)*0.5;
        float rr=sqrt(max(0.0,radius*radius+2.0*radius*mu*t+t*t));
        vec3 rs,ext;float ms;
        atmoMedium(rr,rs,ms,ext);
        tau+=ext*dt;
    }
    return exp(-tau);
}
vec2 atmoTexelUV(vec2 p, ivec2 size) {
    return (clamp(p,0.0,1.0)*vec2(size-1)+0.5)/vec2(size);
}
vec3 atmoTexelUVW(vec3 p, ivec3 size) {
    return (clamp(p,0.0,1.0)*vec3(size-1)+0.5)/vec3(size);
}
vec2 atmoViewUV(vec3 direction, vec3 sun) {
    float denom=length(direction.xz)*length(sun.xz);
    float phi=denom>0.0001 ? acos(clamp(dot(direction.xz,sun.xz)/denom,-1.0,1.0)) : 0.0;
    return vec2(phi/ATMO_PI,atmoElevationUv(direction.y));
}
float atmoDistanceUV(float km) {
    return log(1.0+clamp(km,0.0,ATMO_MAX_DISTANCE))/log(1.0+ATMO_MAX_DISTANCE);
}
#endif
