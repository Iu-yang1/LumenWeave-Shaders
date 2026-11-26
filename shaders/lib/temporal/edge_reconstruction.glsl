// LumenWeave original four-donor edge-adaptive temporal reconstruction.
// Conceptual reference: AMD GPUOpen FSR1 EASU / RCAS and FSR2 reactive
// accumulation. No AMD shader code or official FSR implementation.
float lwUpscaleLuma(vec3 c){return dot(c,vec3(0.2126,0.7152,0.0722));}
float lwEdgeWeight(vec2 offset,vec2 gradient,float contrast){
    float projected=dot(offset,gradient);
    return 1.0/(1.0+contrast*projected*projected*3.0);
}
vec3 lwBoundedDetail(vec3 value,vec3 localMean,vec3 lower,vec3 upper,float strength){
    return clamp(value+(value-localMean)*strength,lower,upper);
}
