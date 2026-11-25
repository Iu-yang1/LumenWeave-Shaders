bool isWall(ivec3 cell, int center) {
    return cell.x == center;
}

vec3 emission(ivec3 cell, int center) {
    if (cell == ivec3(center - 10, center, center) ||
        cell == ivec3(center - 1, center, center)) {
        return vec3(1.0, 0.0, 0.0);
    }
    if (cell == ivec3(center - 6, center, center)) {
        return vec3(0.0, 0.0, 1.0);
    }
    return vec3(0.0);
}
