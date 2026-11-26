#ifdef LW_VOXEL_WEATHER_ACTIVE
#ifndef LW_VOXEL_LIGHT_UNIFORM
#define LW_VOXEL_LIGHT_UNIFORM
uniform sampler3D lwVoxelLight;
#endif
vec4 rainColumn(ivec2 column){
    if(any(lessThan(column,ivec2(0)))||any(greaterThanEqual(column,ivec2(VOXEL_GRID_SIZE)))) return vec4(-1.0);
    return texelFetch(lwVoxelLight,ivec3(column,LW_RAIN_COLUMN_SLICE),0);
}
vec3 rainGeometry(vec3 viewPosition,vec3 normal){
    vec3 relative=(gbufferModelViewInverse*vec4(viewPosition,1.0)).xyz;
    float radius=float(VOXEL_GRID_SIZE)*0.5;
    float coverage=1.0-smoothstep(radius-6.0,radius-2.0,length(relative));
    if(coverage<=0.0) return vec3(1.0,0.0,0.0);
    vec3 cell=relative+cameraPositionFract+vec3(radius);
    ivec2 p=ivec2(floor(cell.xz+normal.xz*0.08));
    vec4 c=rainColumn(p);
    if(c.x<0.0 || cell.y<c.z || cell.y>c.y) return vec3(1.0,0.0,0.0);
    // A known opaque voxel strictly above this surface blocks vertical rain.
    // Blend near cache limits; missing voxels never prove an open sky.
    float exposed=1.0-coverage*smoothstep(0.12,0.70,c.x-cell.y);
    if(normal.y<0.91 || abs(cell.y-c.x)>0.30 || exposed<0.99) return vec3(exposed,0.0,0.0);
    const ivec2 offsets[4]=ivec2[4](ivec2(1,0),ivec2(-1,0),ivec2(0,1),ivec2(0,-1));
    float lower=0.0,higher=0.0,known=0.0;
    for(int i=0;i<4;++i){
        vec4 neighbor=rainColumn(p+offsets[i]);
        if(neighbor.x<0.0) continue;
        known+=1.0;
        lower+=smoothstep(0.25,0.75,c.x-neighbor.x);
        higher+=smoothstep(0.25,0.75,neighbor.x-c.x);
    }
    if(known<4.0) return vec3(exposed,0.0,0.0);
    // Drainage across an open lower neighbour; an enclosed local depression
    // retains water. This is local relief, not a global hydraulic simulation.
    float retention=(1.0-smoothstep(0.0,1.0,lower))*mix(0.35,1.0,higher*0.25);
    return vec3(exposed,retention,coverage);
}
#else
vec3 rainGeometry(vec3 viewPosition,vec3 normal){return vec3(1.0,0.0,0.0);}
#endif
