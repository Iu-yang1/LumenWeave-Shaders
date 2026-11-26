#version 330 compatibility
flat out int castsShadow;

void main() {
    gl_Position = ftransform();
    castsShadow = 1;
#ifdef DISTANT_HORIZONS
    if (dhMaterialId == DH_BLOCK_WATER) {
        castsShadow = 0;
    }
#endif
}
