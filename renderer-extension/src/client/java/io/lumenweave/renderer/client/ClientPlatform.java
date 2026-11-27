package io.lumenweave.renderer.client;

import net.minecraft.client.Minecraft;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.levelgen.WorldOptions;
import net.minecraft.world.level.levelgen.presets.WorldPresets;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.ChunkPos;

public final class ClientPlatform {
    public static void createSmokeWorld(Minecraft client) {
        client.createWorldOpenFlows().createFreshLevel("LumenWeave_Smoke_" + System.currentTimeMillis(),
            MinecraftServer.DEMO_SETTINGS.withGameType(GameType.SPECTATOR), WorldOptions.DEMO_OPTIONS,
            WorldPresets::createNormalWorldDimensions, client.screen);
    }
    public static int chunkX(ChunkPos position) { return position.x(); }
    public static int chunkZ(ChunkPos position) { return position.z(); }
    public static int minSection(ClientLevel level) { return level.getMinSectionY(); }
    public static int maxSection(ClientLevel level) { return level.getMaxSectionY(); }
    private ClientPlatform() {}
}
