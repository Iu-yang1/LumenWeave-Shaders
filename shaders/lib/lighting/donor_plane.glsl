#ifndef LW_DONOR_PLANE
#define LW_DONOR_PLANE

bool donorPlaneDepth(vec3 position,vec3 normalView,vec2 donorUv,out float depth) {
#ifdef LW_STABLE_DYNAMIC
    vec2 rayUv=donorUv;
#else
    vec2 rayUv=unjitteredUv(donorUv,true);
#endif
    vec3 ray=(gbufferProjectionInverse*vec4(rayUv*2.0-1.0,1.0,1.0)).xyz;
    float denominator=dot(normalView,ray);
    depth=-position.z;
    if(denominator*denominator<=0.0004*dot(ray,ray)) return false;
    float distance=dot(normalView,position)/denominator;
    float intersection=-ray.z*distance;
    if(distance<=0.0 || intersection<=0.0 ||
        abs(intersection-depth)>=max(0.25,depth*0.12)) return false;
    depth=intersection;
    return true;
}

#endif
