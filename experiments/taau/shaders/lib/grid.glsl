#ifndef LW_TAAU_GRID
#define LW_TAAU_GRID
#define TAAU_SCALE 0.75 // [0.5 0.67 0.75 0.85 1.0]
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
vec2 displaySize(){return max(vec2(viewWidth,viewHeight),vec2(1.0));}
vec2 renderSize(){return max(floor(displaySize()*TAAU_SCALE),vec2(1.0));}
vec2 renderScale(){return renderSize()/displaySize();}
vec2 jitterPixels(){
    const vec2 seq[8]=vec2[8](vec2(0,-0.16667),vec2(-0.25,0.16667),vec2(0.25,-0.38889),vec2(-0.375,-0.05556),vec2(0.125,0.27778),vec2(-0.125,-0.27778),vec2(0.375,0.05556),vec2(-0.4375,0.38889));
    return seq[frameCounter&7]-vec2(-0.0546875,0.0);
}
vec2 nativeUv(vec2 outputUv){return (outputUv+jitterPixels()/renderSize())*renderScale();}
vec2 outputUvAt(vec2 nativePixel){return (nativePixel+0.5-jitterPixels())/renderSize();}
vec4 scaledClip(vec4 clip){
    vec2 s=renderScale();
    clip.xy=(clip.xy+2.0*jitterPixels()/renderSize()*clip.w)*s+(s-1.0)*clip.w;
    return clip;
}
#endif
