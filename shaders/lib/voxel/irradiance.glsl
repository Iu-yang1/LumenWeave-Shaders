#include "/lib/voxel/grid.glsl"

uniform sampler3D lwVoxelLight;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
uniform usampler3D lwVoxelDirtySampler;
#endif
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/cache_coordinates.glsl"

// Most lookups use hardware filtering. Only ring seams need a manual 8-tap
// reconstruction; clamp to the active domain before wrapping storage indices.
vec4 sampleWrappedVoxelSlab(sampler3D field,vec3 localCell,vec3 cacheOrigin,int slab) {
    float size=float(LW_GRID_SIZE);
    vec3 p=mod(clamp(localCell,vec3(0.5),vec3(size-0.5))+cacheOrigin,size);
    if(all(greaterThanEqual(p,vec3(0.5))) && all(lessThanEqual(p,vec3(size-0.5)))) {
        return textureLod(field,(p+vec3(0.0,0.0,float(slab)*size))/vec3(textureSize(field,0)),0.0);
    }
    vec3 texel=p-0.5;
    ivec3 base=ivec3(floor(texel));
    vec3 fraction=fract(texel);
    vec4 result=vec4(0.0);
    for(int z=0;z<2;++z)for(int y=0;y<2;++y)for(int x=0;x<2;++x) {
        ivec3 offset=ivec3(x,y,z);
        vec3 weight=mix(1.0-fraction,fraction,vec3(offset));
        result+=texelFetch(field,voxelWrap(base+offset)+ivec3(0,0,slab*LW_GRID_SIZE),0)*weight.x*weight.y*weight.z;
    }
    return result;
}
vec4 sampleWrappedVoxelRgbaAtOrigin(sampler3D field,vec3 localCell,vec3 cacheOrigin) {
    return sampleWrappedVoxelSlab(field,localCell,cacheOrigin,0);
}
vec4 sampleLightRgbaAtOrigin(vec3 localCell,vec3 cacheOrigin) {
#ifdef LW_VOXEL_SMOOTH_ACTIVE
    return sampleWrappedVoxelSlab(lwVoxelLight,localCell,cacheOrigin,1);
#else
    return sampleWrappedVoxelRgbaAtOrigin(lwVoxelLight,localCell,cacheOrigin);
#endif
}
vec3 sampleWrappedVoxelAtOrigin(sampler3D field,vec3 localCell,vec3 cacheOrigin) {
    return sampleWrappedVoxelRgbaAtOrigin(field,localCell,cacheOrigin).rgb;
}
vec3 sampleWrappedVoxel(sampler3D field,vec3 localCell) {
    return sampleWrappedVoxelAtOrigin(field,localCell,vec3(voxelCacheOrigin()));
}
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

vec3 sampleVoxelIrradianceSlab(sampler3D field, vec3 relativePosition, vec3 normal, float offset,int slab) {
    vec3 cell = relativePosition + cameraPositionFract + vec3(float(LW_GRID_SIZE) * 0.5);
    vec3 edge = min(cell, float(LW_GRID_SIZE) - cell);
    float weight = smoothstep(0.8, 2.2, min(edge.x, min(edge.y, edge.z)));
    // Outside the guaranteed reversed-culling sphere, prefer vanilla light.
    float radius=float(LW_GRID_SIZE)*0.5;
    weight *= 1.0-smoothstep(radius-5.0,radius-1.0,length(relativePosition));
    if (weight <= 0.0) {
        return vec3(0.0);
    }
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    vec3 sampleCell=cell+normal*offset;
#if defined(ADAPTIVE_SHADING) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
    // The radius-two support mask includes four propagation steps, the
    // diffuse neighbour and the trilinear halo. Unlit tiles are exact zero.
    ivec3 tile=clamp(ivec3(floor(sampleCell/4.0)),ivec3(0),ivec3(LW_GRID_SIZE/4-1));
#ifdef LW_VOXEL_SMOOTH_ACTIVE
    if(slab==1) {
        if(texelFetch(lwVoxelDirtySampler,tile+ivec3(32,0,0),0).r==0u) return vec3(0.0);
    } else
#endif
    if((texelFetch(lwVoxelDirtySampler,tile+ivec3(96,0,0),0).r&4u)==0u) return vec3(0.0);
#endif
    return sampleWrappedVoxelSlab(field,sampleCell,vec3(voxelCacheOrigin()),slab).rgb*weight;
#else
    vec3 uv = (cell + normal * offset) / float(LW_GRID_SIZE);
    return texture(field, uv).rgb * weight;
#endif
}

vec3 sampleVoxelIrradiance(sampler3D field,vec3 relativePosition,vec3 normal,float offset) {
    return sampleVoxelIrradianceSlab(field,relativePosition,normal,offset,0);
}
vec3 voxelIrradiance(vec3 relativePosition, vec3 normal) {
#ifdef LW_VOXEL_SMOOTH_ACTIVE
    return sampleVoxelIrradianceSlab(lwVoxelLight,relativePosition,normal,0.52,1);
#else
    return sampleVoxelIrradiance(lwVoxelLight,relativePosition,normal,0.52);
#endif
}
#ifdef LW_VOXEL_SMOOTH_ACTIVE
vec3 voxelTargetIrradiance(vec3 relativePosition,vec3 normal) {
    return sampleVoxelIrradiance(lwVoxelLight,relativePosition,normal,0.52);
}
#endif

#ifdef LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler3D lwVoxelDiffuse;

vec3 voxelDiffuseBounce(vec3 relativePosition, vec3 normal) {
    return sampleVoxelIrradiance(lwVoxelDiffuse, relativePosition, normal, 1.05);
}
#endif
