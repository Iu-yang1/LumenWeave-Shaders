#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=8,local_size_y=8) in;
const ivec3 workGroups=ivec3(16,16,1);
#ifdef LW_VOXEL_WEATHER_ACTIVE
#include "/lib/voxel/grid.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba16f) writeonly uniform image3D lwVoxelFirst;
uniform float wetness;
uniform float lwRain;
uniform vec3 cameraPositionFract;
void main(){
    ivec2 column=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(column,ivec2(LW_GRID_SIZE)))) return;
    if(max(wetness,lwRain)<=0.001) return;
    // Local x/z column, not the world-wrapped light cache. Negative height
    // represents unknown geometry, never proof of an open column.
    float top=-1.0;
    float radius=float(LW_GRID_SIZE)*0.5-2.0;
    vec2 relative=vec2(column)+0.5-vec2(float(LW_GRID_SIZE)*0.5)-cameraPositionFract.xz;
    float height=sqrt(max(radius*radius-dot(relative,relative),0.0));
    int upper=min(LW_GRID_SIZE-1,int(floor(height+float(LW_GRID_SIZE)*0.5+cameraPositionFract.y-0.5)));
    int lower=max(0,int(ceil(-height+float(LW_GRID_SIZE)*0.5+cameraPositionFract.y-0.5)));
    if(dot(relative,relative)<radius*radius){
        for(int y=upper;y>=lower;--y){
            if(imageLoad(lwVoxelOccupancy,ivec3(column.x,y,column.y)).r>=LW_VOXEL_WALL){
                top=float(y+1);
                break;
            }
        }
    }
    imageStore(lwVoxelFirst,ivec3(column,2*LW_GRID_SIZE+2),vec4(top,float(upper+1),float(lower),0.0));
}
#else
void main(){}
#endif
