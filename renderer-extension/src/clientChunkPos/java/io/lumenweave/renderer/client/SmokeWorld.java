package io.lumenweave.renderer.client;

import net.minecraft.client.Minecraft;

public final class SmokeWorld {
    public static void open(Minecraft client) {
        client.createWorldOpenFlows().openWorld("Demo_World", () -> {});
    }

    private SmokeWorld() {}
}
