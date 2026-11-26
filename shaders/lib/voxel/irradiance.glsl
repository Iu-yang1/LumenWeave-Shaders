#include "/lib/voxel/grid.glsl"

uniform sampler3D lwVoxelLight;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/cache_coordinates.glsl"

// Most lookups use hardware filtering. Only ring seams need a manual 8-tap
// reconstruction; clamp to the active domain before wrapping storage indices.
vec3 sampleWrappedVoxel(sampler3D field,vec3 localCell) {
    float size=float(LW_GRID_SIZE);
    vec3 p=mod(clamp(localCell,vec3(0.5),vec3(size-0.5))+vec3(voxelCacheOrigin()),size);
    if(all(greaterThanEqual(p,vec3(0.5))) && all(lessThanEqual(p,vec3(size-0.5)))) {
        return texture(field,p/size).rgb;
    }
    vec3 texel=p-0.5;
    ivec3 base=ivec3(floor(texel));
    vec3 fraction=fract(texel);
    vec3 result=vec3(0.0);
    for(int z=0;z<2;++z)for(int y=0;y<2;++y)for(int x=0;x<2;++x) {
        ivec3 offset=ivec3(x,y,z);
        vec3 weight=mix(1.0-fraction,fraction,vec3(offset));
        result+=texelFetch(field,voxelWrap(base+offset),0).rgb*weight.x*weight.y*weight.z;
    }
    return result;
}
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

vec3 sampleVoxelIrradiance(sampler3D field, vec3 relativePosition, vec3 normal, float offset) {
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
    return sampleWrappedVoxel(field,cell+normal*offset)*weight;
#else
    vec3 uv = (cell + normal * offset) / float(LW_GRID_SIZE);
    return texture(field, uv).rgb * weight;
#endif
}

vec3 voxelIrradiance(vec3 relativePosition, vec3 normal) {
    return sampleVoxelIrradiance(lwVoxelLight, relativePosition, normal, 0.52);
}

#ifdef LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler3D lwVoxelDiffuse;

vec3 voxelDiffuseBounce(vec3 relativePosition, vec3 normal) {
    return sampleVoxelIrradiance(lwVoxelDiffuse, relativePosition, normal, 1.05);
}
#endif
