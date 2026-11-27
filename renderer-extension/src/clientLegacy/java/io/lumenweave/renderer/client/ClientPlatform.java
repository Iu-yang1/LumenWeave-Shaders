package io.lumenweave.renderer.client;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.ChunkPos;

public final class ClientPlatform {
    public static void createSmokeWorld(Minecraft client) { SmokeWorld.open(client); }
    public static int chunkX(ChunkPos position) { return position.x; }
    public static int chunkZ(ChunkPos position) { return position.z; }
    public static int minSection(ClientLevel level) { return level.getMinSection(); }
    public static int maxSection(ClientLevel level) { return level.getMaxSection() - 1; }
    private ClientPlatform() {}
}
