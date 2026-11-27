package lumenweave.capture.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import org.lwjgl.opengl.GL33C;

public final class GpuStageProfiler {
    private record Scope(String name, int first, int last, List<Scope> children) {}
    private record Frame(int number, Scope root) {}
    private static final ArrayDeque<Scope> stack = new ArrayDeque<>();
    private static final ArrayDeque<Frame> pending = new ArrayDeque<>();
    private static final StringBuilder rows = new StringBuilder();
    private static String label;
    private static long nextPoll;
    private static int remaining;
    private static int frame;

    public static void beginFrame() throws IOException {
        drain();
        if (label == null && System.nanoTime() >= nextPoll) {
            nextPoll = System.nanoTime() + 250_000_000L;
            Path trigger = Path.of("gpu-stages.trigger");
            if (Files.isRegularFile(trigger)) {
                String[] request = Files.readString(trigger).strip().split("\\s+");
                Files.delete(trigger);
                if (request.length != 2 || !request[0].matches("[a-zA-Z0-9_-]+")) {
                    throw new IllegalArgumentException("Expected GPU capture label and frame count");
                }
                remaining = Integer.parseInt(request[1]);
                if (remaining < 1 || remaining > 1200) {
                    throw new IllegalArgumentException("GPU capture needs 1 to 1200 frames");
                }
                label = request[0];
                frame = 0;
                rows.setLength(0);
                rows.append("frame,pass,gpu_ms,self_gpu_ms\n");
            }
        }
        if (label != null && remaining > 0 && pending.size() < 64) {
            push("__frame__");
        }
    }

    public static void begin(String name) {
        if (!stack.isEmpty()) {
            push(name.replace(',', '_'));
        }
    }

    private static void push(String name) {
        int first = GL33C.glGenQueries();
        int last = GL33C.glGenQueries();
        Scope scope = new Scope(name, first, last, new ArrayList<>());
        if (!stack.isEmpty()) {
            stack.peek().children().add(scope);
        }
        stack.push(scope);
        GL33C.glQueryCounter(first, GL33C.GL_TIMESTAMP);
    }

    public static void end() {
        if (stack.size() > 1) {
            GL33C.glQueryCounter(stack.pop().last(), GL33C.GL_TIMESTAMP);
        }
    }

    public static void endFrame() throws IOException {
        if (!stack.isEmpty()) {
            if (stack.size() != 1) {
                throw new IllegalStateException("Unbalanced GPU profiling scopes");
            }
            Scope root = stack.pop();
            GL33C.glQueryCounter(root.last(), GL33C.GL_TIMESTAMP);
            pending.add(new Frame(frame++, root));
            remaining--;
        }
        drain();
    }

    private static void drain() throws IOException {
        while (!pending.isEmpty()) {
            Frame ready = pending.peek();
            if (GL33C.glGetQueryObjecti(ready.root().last(), GL33C.GL_QUERY_RESULT_AVAILABLE) == 0) {
                break;
            }
            pending.remove();
            append(ready.number(), ready.root(), "");
        }
        if (label != null && remaining == 0 && pending.isEmpty()) {
            Files.writeString(Path.of("gpu-stages-" + label + ".csv"), rows);
            System.getLogger("LumenWeave GPU capture").log(System.Logger.Level.INFO,
                "LumenWeave GPU stages " + label + " frames=" + frame
                + " GL error=" + GL33C.glGetError());
            label = null;
        }
    }

    private static long duration(Scope scope) {
        return GL33C.glGetQueryObjectui64(scope.last(), GL33C.GL_QUERY_RESULT)
            - GL33C.glGetQueryObjectui64(scope.first(), GL33C.GL_QUERY_RESULT);
    }

    private static void append(int number, Scope scope, String parent) {
        long inclusive = duration(scope);
        long children = 0;
        for (Scope child : scope.children()) {
            children += duration(child);
        }
        String name = parent.isEmpty() ? scope.name() : parent + "/" + scope.name();
        rows.append(number).append(',').append(name).append(',')
            .append(inclusive / 1_000_000.0).append(',')
            .append((inclusive - children) / 1_000_000.0).append('\n');
        for (Scope child : scope.children()) {
            append(number, child, name);
        }
        GL33C.glDeleteQueries(scope.first());
        GL33C.glDeleteQueries(scope.last());
    }

    private GpuStageProfiler() {}
}
