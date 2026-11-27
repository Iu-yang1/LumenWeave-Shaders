package io.lumenweave.renderer.client;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.TitleScreen;
import org.lwjgl.opengl.GL11C;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class RuntimeSmoke {
    private static final boolean ENABLED = Boolean.getBoolean("lumenweave.renderer.runtimeSmoke");
    private static final boolean FRESH = Boolean.getBoolean("lumenweave.renderer.runtimeSmokeFresh");
    private static final Logger LOG = LoggerFactory.getLogger("LumenWeaveRuntimeSmoke");
    private static long started;
    private static int ticks;
    private static int waiting;
    private static boolean opened;

    public static void tick(Minecraft client) {
        if (!ENABLED) {
            return;
        }
        if (client.level == null || client.player == null) {
            if (++waiting % 200 == 0) {
                LOG.info("Runtime smoke waiting: screen={}",
                    client.screen == null ? "none" : client.screen.getTitle().getString());
                if (!opened && (client.screen instanceof TitleScreen || FRESH)) {
                    opened = true;
                    if (FRESH) {
                        ClientPlatform.createSmokeWorld(client);
                    } else {
                        SmokeWorld.open(client);
                    }
                }
            }
            return;
        }
        if (client.screen != null) {
            client.setScreen(null);
        }
        if (started == 0) {
            started = System.nanoTime();
            LOG.info("Runtime smoke joined: dimension={}, GPU={}, GL={}", client.level.dimension(),
                GL11C.glGetString(GL11C.GL_RENDERER), GL11C.glGetString(GL11C.GL_VERSION));
        }
        ticks++;
        if (ticks >= 200 && System.nanoTime() - started >= 20_000_000_000L) {
            LOG.info("Runtime smoke complete: ticks={}, GL error={}", ticks, GL11C.glGetError());
            client.stop();
        }
    }

    private RuntimeSmoke() {}
}
