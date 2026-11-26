// Camera inactivity proxy. Iris exposes transforms, not actual input events.
// Included only by the one-invocation camera state meter.
uniform ivec3 cameraPositionInt;
uniform ivec3 previousCameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 previousCameraPositionFract;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
#ifndef LW_IDLE_PROJECTION_DECLARED
uniform mat4 gbufferProjection;
#endif
uniform mat4 gbufferPreviousProjection;
uniform int heldItemId;
uniform int heldItemId2;
vec4 lwAdvanceIdle(vec4 prior,float dt){
    vec3 translation=vec3(cameraPositionInt-previousCameraPositionInt)+cameraPositionFract-previousCameraPositionFract;
    // Thresholds deliberately much smaller than a visible mouse movement.
    float rotation=0.0;
    for(int i=0;i<3;++i)rotation+=dot(gbufferModelView[i].xyz-gbufferPreviousModelView[i].xyz,gbufferModelView[i].xyz-gbufferPreviousModelView[i].xyz);
    float zoom=abs(gbufferProjection[0][0]-gbufferPreviousProjection[0][0])+abs(gbufferProjection[1][1]-gbufferPreviousProjection[1][1]);
    bool cameraActive=frameCounter<2 || dot(translation,translation)>0.00000004 || rotation>0.00000004 || zoom>0.0001 ||
        prior.z!=float(heldItemId) || prior.w!=float(heldItemId2);
    float elapsed=cameraActive?0.0:min(prior.x+clamp(dt,0.0,0.25),DOF_IDLE_DELAY+3.0);
    float target=smoothstep(DOF_IDLE_DELAY,DOF_IDLE_DELAY+2.0,elapsed);
    float blend=mix(target,prior.y,exp2(-clamp(dt,0.0,0.25)/(cameraActive?0.12:0.65)));
    return vec4(elapsed,clamp(blend,0.0,1.0),float(heldItemId),float(heldItemId2));
}
