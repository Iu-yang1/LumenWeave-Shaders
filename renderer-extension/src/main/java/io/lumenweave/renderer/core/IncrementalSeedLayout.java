package io.lumenweave.renderer.core;

public record IncrementalSeedLayout(int size) {
    public IncrementalSeedLayout {
        if(size!=32&&size!=64&&size!=96&&size!=128)throw new IllegalArgumentException("seed grid");
    }
    public int tilePlanes(){return (size+63)/64;}
    public int flag(){return size+tilePlanes();}
    public int persistentBase(){return flag()+1;}
    public int supportBase(){return persistentBase()+size;}
    public int depth(){return supportBase()+tilePlanes();}
    public int address(int world){return Math.floorMod(world,size);}
}
