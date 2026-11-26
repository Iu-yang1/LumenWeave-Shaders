#include "/lib/atmosphere/physical_common.glsl"
uniform sampler2D lwAtmoTrans;
#ifndef LW_ATMO_SINGLE_ONLY
uniform sampler2D lwAtmoMulti;
#endif
vec3 atmoSolar(float radius,float mu) {
    float horizon=atmoHorizon(radius);
    if(mu<horizon) return vec3(0.0);
    vec2 uv=vec2((mu-horizon)/max(1.0-horizon,0.0001),(radius-ATMO_GROUND)/(ATMO_TOP-ATMO_GROUND));
    return texture(lwAtmoTrans,atmoTexelUV(uv,textureSize(lwAtmoTrans,0))).rgb;
}
void atmoIntegrate(float radius,vec3 direction,vec3 sun,float maxDistance,bool groundRadiance,int steps,
    out vec3 radiance,out vec3 throughput,out vec3 response) {
    vec2 boundary=atmoBoundary(radius,direction.y);
    float distanceToEnd=min(boundary.x,maxDistance);
    float dt=distanceToEnd/float(steps);
    float cosine=clamp(dot(direction,sun),-1.0,1.0);
    float pr=3.0/(16.0*ATMO_PI)*(1.0+cosine*cosine);
    float g=0.8;
    float denom=max(1.0+g*g-2.0*g*cosine,0.0001);
    float pm=(1.0-g*g)/(4.0*ATMO_PI*denom*sqrt(denom));
    radiance=vec3(0.0);throughput=vec3(1.0);response=vec3(0.0);
    for(int i=0;i<steps;++i) {
        vec3 p=vec3(0.0,radius,0.0)+direction*((float(i)+0.5)*dt);
        float rr=length(p), mu=dot(p,sun)/rr;
        vec3 rs,ext;float ms;
        atmoMedium(rr,rs,ms,ext);
        vec3 solar=atmoSolar(rr,mu);
        vec3 sigma=rs+ms;
        vec3 source=solar*(rs*pr+ms*pm);
#ifndef LW_ATMO_SINGLE_ONLY
        vec2 uv=vec2(mu*0.5+0.5,(rr-ATMO_GROUND)/(ATMO_TOP-ATMO_GROUND));
        source+=texture(lwAtmoMulti,atmoTexelUV(uv,textureSize(lwAtmoMulti,0))).rgb*sigma;
#endif
        vec3 segment=exp(-ext*dt);
        vec3 integral=mix((1.0-segment)/max(ext,vec3(1e-8)),vec3(dt),lessThan(ext*dt,vec3(0.0001)));
        radiance+=throughput*source*integral;
        response+=throughput*sigma*integral;
        throughput*=segment;
    }
    if(groundRadiance && boundary.y>0.5 && boundary.x<=maxDistance) {
        vec3 p=vec3(0.0,radius,0.0)+direction*boundary.x;
        float mu=max(0.0,dot(normalize(p),sun));
        radiance+=throughput*ATMO_GROUND_ALBEDO*mu*atmoSolar(ATMO_GROUND,mu)/ATMO_PI;
        response+=throughput*ATMO_GROUND_ALBEDO;
    }
}
