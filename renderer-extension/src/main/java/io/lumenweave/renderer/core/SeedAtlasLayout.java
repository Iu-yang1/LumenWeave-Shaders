package io.lumenweave.renderer.core;

/** 128-block window can overlap nine sections, so use a 144-block ring. */
public final class SeedAtlasLayout {
    public static final int SIDE=144;
    public static int address(int world){return Math.floorMod(world,SIDE);}
    public static int sectionAddress(int section){return Math.floorMod(section,9)*16;}
    public static int index(int x,int y,int z){return address(x)+SIDE*(address(y)+SIDE*address(z));}
    private SeedAtlasLayout(){}
}