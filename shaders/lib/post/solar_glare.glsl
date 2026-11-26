flat in vec4 lwSolar;
vec3 lwSolarGlare(vec2 uv,vec2 size){
    if(lwSolar.z<=0.0001) return vec3(0.0);
    vec2 aspect=vec2(size.x/max(size.y,1.0),1.0);
    vec2 p=(uv-lwSolar.xy)*aspect;
    float d=length(p);
    vec3 tint=mix(vec3(1.0,0.59,0.30),vec3(1.0,0.95,0.83),smoothstep(0.0,0.48,lwSolar.w));
    float halo=0.22*exp(-d*d*8.0)+0.68*exp(-d*d*100.0);
#ifdef LENS_GHOSTS
    vec2 axis=(lwSolar.xy-0.5)*aspect;
    for(int i=0;i<3;++i) {
        vec2 q=(uv-0.5)*aspect+axis*(0.35+float(i)*0.48);
        float radius=0.045+float(i)*0.026;
        halo+=0.065*exp(-pow(length(q)/radius,2.0));
    }
#endif
#ifdef LENS_STAR
    vec2 a=abs(p);
    halo+=0.12*exp(-min(a.x,a.y)*280.0)*exp(-d*8.0);
#endif
    return tint*halo*(lwSolar.z*GLARE_STRENGTH);
}
