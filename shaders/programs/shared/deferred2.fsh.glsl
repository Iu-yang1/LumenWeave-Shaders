#version 330 compatibility
#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 sceneOutput;

#ifdef LW_MATERIAL_SSR_ACTIVE
/* RENDERTARGETS: 0,8 */
layout(location = 1) out vec4 opaqueOutput;

#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/fog.glsl"
#include "/lib/materials/vanilla.glsl"
#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
#include "/lib/materials/lab_surface.glsl"
#endif
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex12;
#include "/lib/reflection/trace.glsl"

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    sceneOutput = texelFetch(colortex0, pixel, 0);
    opaqueOutput = texelFetch(colortex8, pixel, 0);
    vec4 metadata = texelFetch(colortex12, pixel, 0);
    if (max(metadata.r, max(metadata.g, metadata.b)) <= 0.001) {
        return;
    }
    float depth = texelFetch(depthtex0, pixel, 0).r;
    vec4 materialDepth = texelFetch(colortex2, pixel, 0);
    if (depth >= 1.0 || abs(depth - materialDepth.x) > 0.00000012) {
        return;
    }
    vec4 geometry = texelFetch(colortex1, pixel, 0);
    vec3 normal = decodeNormal(geometry.xy);
    vec3 viewPosition = reconstructViewPosition(texCoord, depth);
    vec3 eye = normalize(worldDirection(-viewPosition));
    vec3 reflected = reflect(-eye, normal);
    // Roughness is needed for the sky fallback. The original albedo is not
    // required for that parameter; F0 and AO are retained in metadata.
    Material material = vanillaMaterial(int(materialDepth.y), vec3(0.5));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
    material = labMaterial(material, vec3(0.5), materialDepth.z, materialDepth.w);
#endif
    float smoothness = 1.0 - smoothstep(0.18, 0.65, material.roughness);
    if (smoothness <= 0.001) {
        return;
    }
    mat3 toView = transpose(mat3(gbufferModelViewInverse));
    vec4 hit = traceScreenReflection(viewPosition + toView * normal * 0.07, toView * reflected, 16);
    if (hit.a <= 0.0) {
        return;
    }
    vec3 sun = sunDirection();
    vec3 skyAmbient = ambientIrradiance(vec2(0.0, geometry.w), normal.y, sun);
    skyAmbient *= mix(1.0, mix(0.58, 1.0, metadata.a), daylight(sun) * (1.0 - rainStrength));
    vec3 fallback = mix(skyRadiance(reflected, sun), skyAmbient, material.roughness * material.roughness);
    // Replace the existing environment contribution, never add a second specular term.
    vec3 correction = (hit.rgb - fallback) * metadata.rgb * (hit.a * smoothness);
    opaqueOutput.rgb = max(opaqueOutput.rgb + correction, vec3(0.0));
    sceneOutput.rgb = applySceneFog(opaqueOutput.rgb, viewPosition);
}
#else
/* RENDERTARGETS: 0 */
void main() {
    sceneOutput = texture(colortex0, texCoord);
}
#endif
