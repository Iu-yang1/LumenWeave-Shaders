#version 330 compatibility
flat in int castsShadow;

/* RENDERTARGETS: 0 */
void main() {
    if (castsShadow == 0) {
        discard;
    }
    gl_FragData[0] = vec4(1.0);
}
