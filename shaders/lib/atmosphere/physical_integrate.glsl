#include "/lib/atmosphere/physical_lookup.glsl"
#ifndef LW_ATMO_SINGLE_ONLY
uniform sampler2D lwAtmoMulti;
#endif
void atmoIntegrateSegment(float radius,vec3 direction,vec3 sun,float startDistance,float endDistance,int steps,
    inout vec3 radiance,inout vec3 throughput,inout vec3 response) {
    if(endDistance<=startDistance) return;
    float lengthToEnd=endDistance-startDistance;
    float cosine=clamp(dot(direction,sun),-1.0,1.0);
    float pr=3.0/(16.0*ATMO_PI)*(1.0+cosine*cosine);
    float g=0.8;
    float denom=max(1.0+g*g-2.0*g*cosine,0.0001);
    float pm=(1.0-g*g)/(4.0*ATMO_PI*denom*sqrt(denom));
    for(int i=0;i<steps;++i) {
        float a=startDistance+lengthToEnd*atmoSegmentCoordinate(float(i)/float(steps));
        float b=startDistance+lengthToEnd*atmoSegmentCoordinate(float(i+1)/float(steps));
        float dt=b-a;
        vec3 p=vec3(0.0,radius,0.0)+direction*((a+b)*0.5);
        float rr=length(p), mu=dot(p,sun)/rr;
        vec3 rs,ext;float ms;
        atmoMedium(rr,rs,ms,ext);
        vec3 solar=atmoSolar(rr,mu);
        vec3 sigma=rs+ms;
        vec3 source=solar*(rs*pr+ms*pm);
#ifndef LW_ATMO_SINGLE_ONLY
        vec2 uv=vec2(atmoElevationUv(mu),atmoAltitudeUv(rr));
        source+=texture(lwAtmoMulti,atmoTexelUV(uv,textureSize(lwAtmoMulti,0))).rgb*sigma;
#endif
        vec3 segment=exp(-ext*dt);
        vec3 integral=mix((1.0-segment)/max(ext,vec3(1e-8)),vec3(dt),lessThan(ext*dt,vec3(0.0001)));
        radiance+=throughput*source*integral;
        response+=throughput*sigma*integral;
        throughput*=segment;
    }
}

void atmoIntegrate(float radius,vec3 direction,vec3 sun,float maxDistance,bool groundRadiance,int steps,
    out vec3 radiance,out vec3 throughput,out vec3 response) {
    vec2 boundary=atmoBoundary(radius,direction.y);
    radiance=vec3(0.0);throughput=vec3(1.0);response=vec3(0.0);
    atmoIntegrateSegment(radius,direction,sun,0.0,min(boundary.x,maxDistance),steps,radiance,throughput,response);
    if(groundRadiance && boundary.y>0.5 && boundary.x<=maxDistance) {
        vec3 p=vec3(0.0,radius,0.0)+direction*boundary.x;
        float mu=max(0.0,dot(normalize(p),sun));
        radiance+=throughput*ATMO_GROUND_ALBEDO*mu*atmoSolar(ATMO_GROUND,mu)/ATMO_PI;
        response+=throughput*ATMO_GROUND_ALBEDO;
    }
}
