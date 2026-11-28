#ifndef LW_WEATHER_STATE
#define LW_WEATHER_STATE
uniform float lwRain;
uniform vec2 lwWindDirection;
uniform vec2 lwWindOffset;
uniform float lwWindTime;
uniform float lwWindPulse;

float weatherGust(vec2 position) {
    float front=sin(dot(position,lwWindDirection)*0.035-lwWindTime*0.63);
    return lwWindPulse*(1.0-WIND_GUSTS*0.18*(1.0-front));
}

vec2 cloudWindPosition(vec2 position,float time) {
#if WEATHER_COUPLING == 1
    return position-lwWindOffset;
#else
    return position+time*vec2(1.1,0.40);
#endif
}

vec2 cloudWindHistoryOffset(float elapsed) {
#if WEATHER_COUPLING == 1
    float delta=elapsed*WIND_SPEED;
    float travel=delta-4.0*WIND_GUSTS*cos((lwWindTime-delta*0.5)*0.11)*sin(delta*0.055);
    return -lwWindDirection*travel;
#else
    return vec2(1.1,0.40)*elapsed;
#endif
}
#endif
