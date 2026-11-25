package lumenweave.bench;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets = "com.mojang.blaze3d.systems.RenderSystem", remap = false)
public abstract class FrameCapture {
    @Unique private static final System.Logger lw$logger = System.getLogger("LumenWeave Frame Capture");
    @Unique private static final long[] lw$intervals = new long[300_000];
    @Unique private static final Path lw$trigger = Path.of("capture.trigger");
    @Unique private static long lw$nextPoll;
    @Unique private static long lw$until;
    @Unique private static long lw$last;
    @Unique private static int lw$count;
    @Unique private static String lw$label;

    @Inject(method = "flipFrame(J)V", at = @At("HEAD"), remap = false)
    private static void lw$record(long window, CallbackInfo callback) {
        long now = System.nanoTime();
        if (lw$count > 0 || lw$last != 0) {
            lw$intervals[lw$count++] = now - lw$last;
            lw$last = now;
            if (now >= lw$until || lw$count == lw$intervals.length) {
                lw$finish();
            }
        } else if (now >= lw$nextPoll) {
            lw$nextPoll = now + 500_000_000L;
            try {
                if (Files.isRegularFile(lw$trigger)) {
                    String[] request = Files.readString(lw$trigger).strip().split("\\s+");
                    Files.delete(lw$trigger);
                    if (request.length != 2 || !request[0].matches("[a-zA-Z0-9_-]+")) {
                        throw new IllegalArgumentException("Expected capture label and seconds");
                    }
                    int seconds = Integer.parseInt(request[1]);
                    if (seconds < 1 || seconds > 120) {
                        throw new IllegalArgumentException("Capture duration must be 1–120 seconds");
                    }
                    lw$label = request[0];
                    lw$last = System.nanoTime();
                    lw$until = lw$last + seconds * 1_000_000_000L;
                }
            } catch (IOException | IllegalArgumentException error) {
                lw$logger.log(System.Logger.Level.WARNING, "Cannot start a capture from " + lw$trigger, error);
            }
        }
    }

    @Unique
    private static void lw$finish() {
        try {
            StringBuilder output = new StringBuilder(lw$count * 12).append("frame_ns\n");
            for (int index = 0; index < lw$count; index++) {
                output.append(lw$intervals[index]).append('\n');
            }
            Files.writeString(Path.of("capture-" + lw$label + ".csv"), output);
        } catch (IOException error) {
            lw$logger.log(System.Logger.Level.WARNING, "Cannot write capture " + lw$label, error);
        } finally {
            lw$count = 0;
            lw$last = 0;
        }
    }
}
