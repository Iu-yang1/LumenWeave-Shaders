import java.io.IOException;
import java.nio.FloatBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import org.lwjgl.BufferUtils;

import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL43C.*;
import org.lwjgl.opengl.GL;

public class VoxelGpuBench {
    private static final int WARMUP = 40;
    private static final int SAMPLES = 200;
    private static final String[] WORLD_STAGES = {
        "begin", "terrain_injection", "prepare", "prepare1", "prepare2", "prepare3", "prepare4", "prepare5"
    };

    public static void main(String[] args) throws IOException {
        if (args.length != 1 && (args.length != 3 || !args[1].equals("--world"))) {
            throw new IllegalArgumentException("Expected expanded shader directory and optional --world SIZE");
        }
        if (!glfwInit()) {
            throw new IllegalStateException("GLFW initialization failed");
        }
        try {
            glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
            glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
            long window = glfwCreateWindow(32, 32, "LumenWeave compute benchmark", 0, 0);
            if (window == 0) {
                throw new IllegalStateException("OpenGL 4.3 context unavailable");
            }
            glfwMakeContextCurrent(window);
            GL.createCapabilities();
            System.out.printf("%s | %s | %s%n", glGetString(GL_VENDOR), glGetString(GL_RENDERER),
                glGetString(GL_VERSION));
            if (args.length == 3) {
                int size = Integer.parseInt(args[2]);
                measureWorld(Path.of(args[0]), size);
                checkScreenGi(Path.of(args[0], "screen-gi.csh"));
                checkScreenGiHistory(Path.of(args[0], "screen-gi-history.csh"));
                checkScreenGiSpatial(Path.of(args[0], "screen-gi-spatial.csh"));
                checkDistantTaa(Path.of(args[0], "distant-taa.csh"));
                checkHistoryFilter(Path.of(args[0], "taa-filter.csh"));
                checkShadowFilter(Path.of(args[0], "shadow-filter.csh"));
                checkWaterWaves(Path.of(args[0], "water-waves.csh"));
                checkVegetationWind(Path.of(args[0], "vegetation-wind.csh"));
                checkDimensionLighting(Path.of(args[0], "dimension-lighting.csh"));
                checkSpatialAa(Path.of(args[0], "spatial-aa.csh"));
            } else {
                measureProbe(Path.of(args[0]));
            }
            glfwDestroyWindow(window);
        } finally {
            glfwTerminate();
        }
    }

    private static void measureProbe(Path directory) throws IOException {
        int[] programs = new int[3];
        String[] names = {"begin.csh", "begin1.csh", "begin2.csh"};
        for (int index = 0; index < programs.length; index++) {
            programs[index] = compile(GL_COMPUTE_SHADER, Files.readString(directory.resolve(names[index])));
            bindImages(programs[index], "lwSeed", "lwFirst", "lwSecond");
        }
        int storage = glGenBuffers();
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, storage);
        glBufferData(GL_SHADER_STORAGE_BUFFER, 16, GL_DYNAMIC_COPY);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, storage);
        System.out.println("size,samples,median_ms,p95_ms,p99_ms,texture_mib");
        for (int size : new int[]{32, 64, 96, 128}) {
            measure(size, programs);
        }
        for (int program : programs) {
            glDeleteProgram(program);
        }
        glDeleteBuffers(storage);
    }

    private static int compile(int stage, String source) {
        int shader = glCreateShader(stage);
        glShaderSource(shader, source);
        glCompileShader(shader);
        if (glGetShaderi(shader, GL_COMPILE_STATUS) == GL_FALSE) {
            throw new IllegalStateException(glGetShaderInfoLog(shader));
        }
        int program = glCreateProgram();
        glAttachShader(program, shader);
        glLinkProgram(program);
        glDeleteShader(shader);
        if (glGetProgrami(program, GL_LINK_STATUS) == GL_FALSE) {
            throw new IllegalStateException(glGetProgramInfoLog(program));
        }
        return program;
    }

    private static void bindImages(int program, String... images) {
        glUseProgram(program);
        glUniform1i(glGetUniformLocation(program, "hasSkylight"), GL_TRUE);
        for (int index = 0; index < images.length; index++) {
            int location = glGetUniformLocation(program, images[index]);
            if (location != -1) {
                glUniform1i(location, index);
            }
        }
    }

    private static void measureWorld(Path directory, int size) throws IOException {
        int[] programs = new int[WORLD_STAGES.length];
        for (int stage = 0; stage < programs.length; stage++) {
            programs[stage] = stage == 1
                ? compile(GL_VERTEX_SHADER, "#version 430 core\nin vec3 position;\n"
                    + Files.readString(directory.resolve("inject.glsl"))
                    + "\nvoid main() { injectTerrainVoxel(position); gl_Position = vec4(0.0, 0.0, 0.0, 1.0); }\n")
                : compile(GL_COMPUTE_SHADER, Files.readString(directory.resolve(WORLD_STAGES[stage] + ".csh")));
            bindImages(programs[stage], "lwVoxelOccupancy", "lwVoxelFirst", "lwVoxelSecond");
        }
        int[] volumes = new int[3];
        int[] formats = {GL_R32UI, GL_RGBA16F, GL_RGBA16F};
        glGenTextures(volumes);
        for (int index = 0; index < volumes.length; index++) {
            glBindTexture(GL_TEXTURE_3D, volumes[index]);
            glTexStorage3D(GL_TEXTURE_3D, 1, formats[index], size, size, size);
            glBindImageTexture(index, volumes[index], 0, true, 0, GL_READ_WRITE, formats[index]);
        }
        int vao = glGenVertexArrays();
        glBindVertexArray(vao);
        glEnable(GL_RASTERIZER_DISCARD);
        glUseProgram(programs[1]);
        glUniformMatrix4fv(glGetUniformLocation(programs[1], "shadowModelViewInverse"), false,
            new float[]{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1});
        int fractionLocation = glGetUniformLocation(programs[1], "cameraPositionFract");
        int position = glGetAttribLocation(programs[1], "position");
        int midBlock = glGetAttribLocation(programs[1], "at_midBlock");
        int blockId = glGetAttribLocation(programs[1], "mc_Entity");
        float fraction = 0.75f;
        glUniform3f(fractionLocation, fraction, fraction, fraction);
        int[] queries = new int[SAMPLES * (programs.length + 1)];
        glGenQueries(queries);
        for (int frame = -WARMUP; frame < SAMPLES; frame++) {
            worldFrame(programs, queries, frame, position, midBlock, blockId, fraction, true, size);
        }
        long[][] elapsed = new long[programs.length + 1][SAMPLES];
        for (int frame = 0; frame < SAMPLES; frame++) {
            int start = frame * elapsed.length;
            long first = glGetQueryObjectui64(queries[start], GL_QUERY_RESULT);
            long previous = first;
            for (int stage = 0; stage < programs.length; stage++) {
                long end = glGetQueryObjectui64(queries[start + stage + 1], GL_QUERY_RESULT);
                elapsed[stage][frame] = end - previous;
                previous = end;
            }
            elapsed[programs.length][frame] = previous - first;
        }
        checkWorldValues(volumes[1], true, size);
        checkWorldBounce(volumes[2], true, size);
        fraction = 0.125f;
        glUseProgram(programs[1]);
        glUniform3f(fractionLocation, fraction, fraction, fraction);
        worldFrame(programs, queries, -1, position, midBlock, blockId, fraction, true, size);
        checkWorldValues(volumes[1], true, size);
        worldFrame(programs, queries, -1, position, midBlock, blockId, fraction, false, size);
        checkWorldValues(volumes[1], false, size);
        checkWorldBounce(volumes[2], false, size);
        int error = glGetError();
        if (error != GL_NO_ERROR) {
            throw new IllegalStateException("OpenGL error " + error);
        }
        System.out.println("P4 readback: RGB mix, attenuation, wall, grid edge, sub-block camera shift, diffuse bounce, and removal passed");
        System.out.printf(java.util.Locale.ROOT, "grid=%d cubed, images=%.3f MiB%n", size,
            20.0 * size * size * size / (1024 * 1024));
        System.out.println("stage,samples,median_ms,p95_ms,p99_ms");
        for (int stage = 0; stage < elapsed.length; stage++) {
            Arrays.sort(elapsed[stage]);
            System.out.printf(java.util.Locale.ROOT, "%s,%d,%.4f,%.4f,%.4f%n",
                stage < programs.length ? WORLD_STAGES[stage] : "total", SAMPLES,
                percentile(elapsed[stage], 0.5), percentile(elapsed[stage], 0.95), percentile(elapsed[stage], 0.99));
        }
        glDeleteQueries(queries);
        glDeleteVertexArrays(vao);
        glDeleteTextures(volumes);
        for (int program : programs) {
            glDeleteProgram(program);
        }
    }

    private static void worldFrame(int[] programs, int[] queries, int frame,
                                   int position, int midBlock, int blockId, float fraction, boolean emitters, int size) {
        int start = frame * (programs.length + 1);
        if (frame >= 0) {
            glQueryCounter(queries[start], GL_TIMESTAMP);
        }
        for (int stage = 0; stage < programs.length; stage++) {
            glUseProgram(programs[stage]);
            if (stage == 1) {
                float origin = size / 2.0f + fraction;
                if (emitters) {
                    injectBlock(position, midBlock, blockId, origin, 14, 16, 16, 10011, 15);
                    injectBlock(position, midBlock, blockId, origin, 18, 16, 16, 10012, 15);
                    injectBlock(position, midBlock, blockId, origin, 0, 4, 4, 10011, 15);
                }
                injectBlock(position, midBlock, blockId, origin, 1, 4, 4, 10022, 0);
            } else {
                glDispatchCompute(size / 4, size / 4, size / 4);
            }
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_TEXTURE_FETCH_BARRIER_BIT);
            if (frame >= 0) {
                glQueryCounter(queries[start + stage + 1], GL_TIMESTAMP);
            }
        }
    }

    private static void injectBlock(int position, int midBlock, int blockId, float origin,
                                    int column, int row, int slice, int id, int strength) {
        glVertexAttrib3f(position, column - origin, row - origin, slice - origin);
        glVertexAttrib4f(midBlock, 32.0f, 32.0f, 32.0f, strength);
        glVertexAttrib4f(blockId, id, 0.0f, 0.0f, 0.0f);
        glDrawArrays(GL_POINTS, 0, 1);
    }

    private static void checkWorldValues(int texture, boolean emitters, int size) {
        FloatBuffer pixels = readVolume(texture, size);
        if (!emitters) {
            checkDark(pixels);
            return;
        }
        float mixed = 1.7f * 0.73f * 0.73f;
        checkCell(pixels, size, 14, 16, 16, 1.7f, 1.7f * 0.63f, 1.7f * 0.33f);
        checkCell(pixels, size, 16, 16, 16, mixed, mixed * 0.72f, mixed);
        checkCell(pixels, size, 0, 5, 4, 1.7f * 0.73f, 1.7f * 0.63f * 0.73f, 1.7f * 0.33f * 0.73f);
        checkCell(pixels, size, 1, 4, 4, 0.0f, 0.0f, 0.0f);
        checkCell(pixels, size, 4, 4, 4, 0.0f, 0.0f, 0.0f);
        checkCell(pixels, size, size - 1, 4, 4, 0.0f, 0.0f, 0.0f);
    }

    private static void checkWorldBounce(int texture, boolean emitters, int size) {
        FloatBuffer pixels = readVolume(texture, size);
        if (!emitters) {
            checkDark(pixels);
            return;
        }
        float incident = 1.7f * 0.12f;
        checkCell(pixels, size, 0, 4, 4, incident * 0.52f, incident * 0.63f * 0.038f,
            incident * 0.33f * 0.03f);
        checkCell(pixels, size, 1, 4, 4, 0.0f, 0.0f, 0.0f);
        checkCell(pixels, size, 4, 4, 4, 0.0f, 0.0f, 0.0f);
    }

    private static FloatBuffer readVolume(int texture, int size) {
        FloatBuffer pixels = BufferUtils.createFloatBuffer(size * size * size * 4);
        glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
        glBindTexture(GL_TEXTURE_3D, texture);
        glGetTexImage(GL_TEXTURE_3D, 0, GL_RGBA, GL_FLOAT, pixels);
        return pixels;
    }

    private static void checkDark(FloatBuffer pixels) {
        for (int offset = 0; offset < pixels.capacity(); offset++) {
            if (pixels.get(offset) != 0.0f) {
                throw new IllegalStateException("Stale radiance after source removal at offset " + offset);
            }
        }
    }

    private static void checkCell(FloatBuffer pixels, int size, int column, int row, int slice, float... expected) {
        int offset = 4 * ((slice * size + row) * size + column);
        for (int channel = 0; channel < expected.length; channel++) {
            float actual = pixels.get(offset + channel);
            if (!(Math.abs(actual - expected[channel]) <= 0.0025f)) {
                throw new IllegalStateException("Unexpected radiance at " + column + "," + row + "," + slice
                    + " channel " + channel + ": " + actual + ", expected " + expected[channel]);
            }
        }
    }

    private static void checkScreenGi(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "colortex0", "colortex1", "colortex2", "depthtex0");
        int[] textures = {
            fixtureTexture(0, new float[]{
                0.8f, 0.15f, 0.10f, 1, 0.8f, 0.15f, 0.10f, 1,
                0.8f, 0.15f, 0.10f, 1, 0.8f, 0.15f, 0.10f, 1
            }),
            fixtureTexture(1, new float[]{0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1}),
            fixtureTexture(2, new float[]{
                0.28f, 10020, 0, 0, -1, 10020, 0, 0,
                0.28f, 10020, 0, 0, 0.28f, 10020, 0, 0
            }),
            fixtureTexture(3, new float[]{0.28f, 0, 0, 0, 0.28f, 0, 0, 0, 0.28f, 0, 0, 0, 1, 0, 0, 0})
        };
        glUniformMatrix4fv(glGetUniformLocation(program, "gbufferProjection"), false,
            new float[]{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -0.2f, 0, 0, 0, -1, 1});
        glUniformMatrix4fv(glGetUniformLocation(program, "gbufferProjectionInverse"), false,
            new float[]{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -5, 0, 0, 0, -5, 1});
        float[] bounce = readShaderOutput(16);
        if (!(bounce[0] > bounce[1] && bounce[1] > bounce[2] && bounce[2] > 0.0f)) {
            throw new IllegalStateException("Expected a red diffuse bounce: " + Arrays.toString(bounce));
        }
        for (int offset = 4; offset < bounce.length; offset++) {
            if (bounce[offset] != 0.0f) {
                throw new IllegalStateException("Unexpected bounce from invalid terrain depth, a backface, or sky");
            }
        }
        int error = glGetError();
        if (error != GL_NO_ERROR) {
            throw new IllegalStateException("Screen GI OpenGL error " + error);
        }
        System.out.println("SSGI readback: colored bounce, terrain depth, backface, and sky rejection passed");
        glDeleteTextures(textures);
        glDeleteProgram(program);
    }

    private static void checkScreenGiHistory(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "colortex6", "colortex7");
        float[] identity = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
        for (String uniform : new String[]{
            "gbufferModelViewInverse", "gbufferPreviousModelView", "gbufferPreviousProjection"
        }) {
            glUniformMatrix4fv(glGetUniformLocation(program, uniform), false, identity);
        }
        int[] textures = {
            fixtureTexture(0, 2, new float[]{
                0.11f, 0.11f, 0.11f, 2, 0.3f, 0.3f, 0.3f, 3,
                0.3f, 0.3f, 0.3f, 0, 0.12f, 0.12f, 0.12f, 2
            }),
            fixtureTexture(1, 2, new float[]{
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0
            })
        };
        float[] result = readShaderOutput(36);
        float[] expectedRed = {0.10585f, 0.1078f, 0.1f, 0.1f, 0.01f, 0, 0.1f, 0.1f};
        for (int index = 0; index < expectedRed.length; index++) {
            for (int channel = 0; channel < 3; channel++) {
                float expected = index == 5 && channel == 1 ? expectedRed[0] : expectedRed[index];
                if (!(Math.abs(result[index * 4 + channel] - expected) < 0.00001f)) {
                    throw new IllegalStateException("Unexpected screen GI history: " + Arrays.toString(result));
                }
            }
        }
        float[] projected = Arrays.copyOfRange(result, 32, 36);
        if (!Arrays.equals(projected, new float[]{0.625f, 0.5f, 2.0f, 1.0f})) {
            throw new IllegalStateException("Unexpected custom projection: " + Arrays.toString(projected));
        }
        if (glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Screen GI history OpenGL error");
        }
        System.out.println("SSGI history: weighted reuse, custom projection, depth/normal/clear, light change, and bounds passed");
        glDeleteTextures(textures);
        glDeleteProgram(program);
    }

    private static void checkScreenGiSpatial(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "colortex1", "colortex9", "colortex10");
        float[] normals = new float[64];
        int backFacing = (3 * 4 + 1) * 4;
        normals[backFacing] = normals[backFacing + 1] = 1.0f;
        int[] textures = {
            fixtureTexture(0, 4, normals),
            fixtureTexture(1, 2, new float[]{
                0.25f, 0, 0, 2, 0, 0.5f, 0, 4,
                0, 0, 0.75f, 2, 1, 1, 1, 0
            }),
            fixtureTexture(2, 2, new float[]{
                0.125f, 0, 0, 0.5f, 0, 0.25f, 0, 0.75f,
                0, 0, 0.5f, 1, 1, 1, 1, 1
            })
        };
        float[] expected = {
            0.25f, 0, 0, 0, 0.125f, 0, 0, 0.5f,
            0, 0, 0.25f, 0, 0, 0, 0, 0,
            0, 0.5f, 0, 0, 0, 0.25f, 0, 0.75f,
            0, 0, 0.75f, 0, 0, 0, 0.5f, 1,
            0, 0, 0, 0, 0, 0, 0, 0
        };
        float[] result = readShaderOutput(expected.length);
        if (!Arrays.equals(result, expected) || glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Unexpected spatial GI reconstruction: " + Arrays.toString(result));
        }
        System.out.println("SSGI spatial: depth/normal edges, invalid donors, fallback, and distance cutoff passed");
        glDeleteTextures(textures);
        glDeleteProgram(program);
    }

    private static void checkDistantTaa(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "colortex0", "colortex1", "colortex2", "colortex4", "colortex5",
            "depthtex0", "depthtex1", "dhDepthTex0", "dhDepthTex1");
        float[] normals = new float[16];
        normals[6] = -1;
        float[] depths = {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0.25f, 0, 0, 0};
        int[] textures = {
            fixtureTexture(0, new float[]{
                0.1f, 0.1f, 0.1f, 1, 0.2f, 0.2f, 0.2f, 1,
                0.2f, 0.2f, 0.2f, 1, 0.1f, 0.1f, 0.1f, 1
            }),
            fixtureTexture(1, normals),
            fixtureTexture(2, new float[]{-1, 0, 0, 0, -1, 0, 0, 0, -1, 0, 0, 0, 0.25f, 0, 0, 0}),
            fixtureTexture(3, new float[]{
                0.12f, 0.12f, 0.12f, 2, 0.12f, 0.12f, 0.12f, -2.4f,
                0.12f, 0.12f, 0.12f, 2, 0.12f, 0.12f, 0.12f, 2
            }),
            fixtureTexture(4, normals),
            fixtureTexture(5, depths),
            fixtureTexture(6, depths),
            fixtureTexture(7, new float[]{0.25f, 0, 0, 0, 0.2f, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0}),
            fixtureTexture(8, new float[]{0.25f, 0, 0, 0, 0.4f, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0})
        };
        float[] identity = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
        for (String name : new String[]{"gbufferModelViewInverse", "gbufferPreviousModelView",
                "gbufferPreviousProjection", "dhPreviousProjection"}) {
            glUniformMatrix4fv(glGetUniformLocation(program, name), false, identity);
        }
        float[] inverse = identity.clone();
        inverse[10] = 4;
        glUniformMatrix4fv(glGetUniformLocation(program, "gbufferProjectionInverse"), false, inverse);
        glUniformMatrix4fv(glGetUniformLocation(program, "dhProjectionInverse"), false, inverse);
        glUniform1f(glGetUniformLocation(program, "viewWidth"), 1280);
        glUniform1f(glGetUniformLocation(program, "viewHeight"), 720);
        float[] result = readShaderOutput(16);
        for (int index = 0; index < result.length; index++) {
            int pixel = index / 4;
            float expected = index % 4 == 3
                ? (pixel == 1 ? -2.4f : 2) : pixel == 1 ? 0.1376f : pixel == 2 ? 0.1264f : 0.1184f;
            if (!(Math.abs(result[index] - expected) < 0.0001f)) {
                throw new IllegalStateException("Unexpected distant TAA history: " + Arrays.toString(result));
            }
        }
        float[] skyDepths = {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};
        glActiveTexture(GL_TEXTURE0 + 5);
        glBindTexture(GL_TEXTURE_2D, textures[5]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 4, 1, GL_RGBA, GL_FLOAT, skyDepths);
        result = readShaderOutput(16);
        if (result[11] != 0 || result[15] != 0) {
            throw new IllegalStateException("Clear sky or water-only edge acquired opaque history");
        }
        inverse[10] = 400;
        glUniformMatrix4fv(glGetUniformLocation(program, "gbufferProjectionInverse"), false, inverse);
        float[] edgeDepths = {1, 0, 0, 0, 1, 0, 0, 0, 0.1f, 0, 0, 0, 0.25f, 0, 0, 0};
        for (int unit : new int[]{2, 5, 6}) {
            glActiveTexture(GL_TEXTURE0 + unit);
            glBindTexture(GL_TEXTURE_2D, textures[unit]);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 4, 1, GL_RGBA, GL_FLOAT, edgeDepths);
        }
        float[] farHistory = {
            0.12f, 0.12f, 0.12f, 200, 0.12f, 0.12f, 0.12f, 200,
            0.12f, 0.12f, 0.12f, 200, 0.12f, 0.12f, 0.12f, 200
        };
        glActiveTexture(GL_TEXTURE0 + 3);
        glBindTexture(GL_TEXTURE_2D, textures[3]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 4, 1, GL_RGBA, GL_FLOAT, farHistory);
        result = readShaderOutput(16);
        if (Math.abs(result[11] - 200) > 0.001f || Math.abs(result[8] - 0.1224f) > 0.00001f) {
            throw new IllegalStateException("Distant foreground dilation or stronger distant accumulation failed");
        }
        if (glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Distant TAA OpenGL error");
        }
        System.out.println("Distant TAA: opaque/water blending, sky-edge coverage, clear sky rejection, and native terrain passed");
        glDeleteTextures(textures);
        glDeleteProgram(program);
    }

    private static void checkHistoryFilter(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "colortex4", "colortex5");
        float[] normals = new float[16];
        normals[12] = 1;
        int[] textures = {
            fixtureTexture(0, new float[]{
                0.1f, 0.2f, 0.3f, 2, 0.3f, 0.4f, 0.5f, 2,
                9, 9, 9, -2, 0.6f, 0.6f, 0.6f, 200
            }),
            fixtureTexture(1, normals)
        };
        float[] result = readShaderOutput(28);
        float[] expected = {
            0.2f, 0.3f, 0.4f, 1, 0.3f, 0.4f, 0.5f, 0.5f, 0, 0, 0, 0, 9, 9, 9, 0.5f,
            0.6f, 0.6f, 0.6f, 1, 0, 0, 0, 0, 0, 0, 0, 0
        };
        for (int index = 0; index < result.length; ++index) {
            if (!(Math.abs(result[index] - expected[index]) < 0.00001f)) {
                throw new IllegalStateException("TAA subpixel filtering or class/depth rejection: " + Arrays.toString(result));
            }
        }
        if (glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("TAA filter OpenGL error");
        }
        System.out.println("TAA filter: subpixel interpolation, far normals, and class/depth/normal/bounds rejection passed");
        glDeleteTextures(textures);
        glDeleteProgram(program);
    }

    private static void checkShadowFilter(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "shadowtex0");
        int texture = fixtureTexture(0, new float[]{0.2f, 0, 0, 0, 0.8f, 0, 0, 0, 0.2f, 0, 0, 0, 0.8f, 0, 0, 0});
        float[] result = readShaderOutput(16);
        float[] expected = {0, 0.5f, 1, 0};
        for (int index = 0; index < result.length; ++index) {
            if (!(Math.abs(result[index] - expected[index / 4]) < 0.00001f)) {
                throw new IllegalStateException("Shadow subpixel comparison or border: " + Arrays.toString(result));
            }
        }
        if (glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Shadow filter OpenGL error");
        }
        System.out.println("Shadow filter: continuous comparison, lit/shadow interiors, and border clamp passed");
        glDeleteTextures(texture);
        glDeleteProgram(program);
    }

    private static void checkWaterWaves(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        glUseProgram(program);
        float[] result = readShaderOutput(16);
        float movement = (float)Math.hypot(result[0] - result[4], result[1] - result[5]);
        if (!(result[2] > 0.005f && result[2] < 0.254f && movement > 0.00001f && movement < 0.02f
                && result[10] < 0.000001f && result[14] < 0.000001f) || glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Water slope continuity or pixel/time filtering: " + Arrays.toString(result));
        }
        System.out.println("Water waves: bounded slopes, continuous motion, spatial and temporal filtering passed");
        glDeleteProgram(program);
    }

    private static void checkVegetationWind(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        glUseProgram(program);
        float[] first = readShaderOutput(28);
        glUniform1f(glGetUniformLocation(program, "frameTimeCounter"), 1);
        float[] second = readShaderOutput(28);
        float movement = 0;
        for (int channel = 0; channel < 3; channel++) {
            movement += Math.abs(first[12 + channel] - second[12 + channel]);
            if (first[channel] != 0 || first[16 + channel] != 0 || first[20 + channel] != 0
                    || Math.abs(first[4 + channel] - first[8 + channel]) > 0.000001f) {
                throw new IllegalStateException("Vegetation roots, distance, material or tall-plant seam");
            }
        }
        for (float value : first) {
            if (!Float.isFinite(value) || Math.abs(value) > 1) {
                throw new IllegalStateException("Unbounded vegetation displacement");
            }
        }
        if (movement < 0.00001f || glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Vegetation motion or OpenGL error");
        }
        System.out.println("Vegetation: anchored roots, tall-plant seams, leaf motion, material and distance cutoff passed");
        glDeleteProgram(program);
    }

    private static void checkDimensionLighting(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        glUseProgram(program);
        float[] identity = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
        glUniformMatrix4fv(glGetUniformLocation(program, "gbufferModelViewInverse"), false, identity);
        glUniform3f(glGetUniformLocation(program, "sunPosition"), 0, 1, 0);
        glUniform3f(glGetUniformLocation(program, "fogColor"), 0.4f, 0.2f, 0.1f);
        glUniform1f(glGetUniformLocation(program, "fogStart"), 8);
        glUniform1f(glGetUniformLocation(program, "fogEnd"), 64);
        glUniform1i(glGetUniformLocation(program, "dhRenderDistance"), 1024);
        float[] fog = {0.13286832f, 0.03310477f, 0.01002283f};
        float[] scene = {0.2f, 0.3f, 0.4f};
        float[][] ambient = {{0.015f, 0.015f, 0.015f}, {0.1346f, 0.0874f, 0.0662f}, {0.155f, 0.145f, 0.205f}};
        for (int dimension = 0; dimension < 3; ++dimension) {
            glUniform1i(glGetUniformLocation(program, "hasSkylight"), dimension == 0 ? GL_TRUE : GL_FALSE);
            glUniform1i(glGetUniformLocation(program, "hasCeiling"), dimension == 1 ? GL_TRUE : GL_FALSE);
            glUniform1f(glGetUniformLocation(program, "ambientLight"), dimension == 1 ? 0.1f : 0);
            glUniform3f(glGetUniformLocation(program, "sunPosition"), 0, dimension == 0 ? 1 : 0, 0);
            float[] result = readShaderOutput(44);
            for (float value : result) {
                if (!Float.isFinite(value)) {
                    throw new IllegalStateException("Non-finite dimension lighting: " + dimension);
                }
            }
            if (result[40] != 0 || result[41] != 1 || result[42] != 0) {
                throw new IllegalStateException("Invalid dimension celestial basis: " + dimension);
            }
            for (int channel = 0; channel < 3; ++channel) {
                float solar = dimension == 0 ? new float[]{4.2f, 4.074f, 3.822f}[channel] : 0;
                float lunar = dimension == 0 ? new float[]{0.16f, 0.19f, 0.24f}[channel] : 0;
                float block = new float[]{1.12f, 0.69f, 0.39f}[channel];
                if (Math.abs(result[channel] - solar) > 0.00001f
                        || Math.abs(result[4 + channel] - lunar) > 0.00001f
                        || Math.abs(result[8 + channel] - ambient[dimension][channel]) > 0.00001f
                        || Math.abs(result[12 + channel] - ambient[dimension][channel] - block) > 0.00001f) {
                    throw new IllegalStateException("Dimension direct, ambient, or block lighting: " + dimension);
                }
                if (dimension != 0) {
                    float zenith = dimension == 1 ? fog[channel] : new float[]{0.004f, 0.003f, 0.012f}[channel];
                    float haze = dimension == 1 ? 1 : 1 - (float)Math.exp(-176.0 / (1024 * 0.85));
                    float fogged = scene[channel] * (1 - haze) + fog[channel] * haze;
                    if (Math.abs(result[16 + channel] - fog[channel]) > 0.00001f
                            || Math.abs(result[20 + channel] - zenith) > 0.00001f
                            || Math.abs(result[24 + channel] - scene[channel]) > 0.00001f
                            || Math.abs(result[28 + channel] - scene[channel]) > 0.00001f
                            || Math.abs(result[32 + channel] - ambient[dimension][channel] * 0.497976f) > 0.00001f
                            || Math.abs(result[36 + channel] - fogged) > 0.00001f) {
                        throw new IllegalStateException("Dimension sky, cloud/shaft suppression, surface, or DH fog: " + dimension);
                    }
                }
            }
        }
        if (glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Dimension lighting OpenGL error");
        }
        System.out.println("Dimensions: direct/ambient/block light, fog, surface shading, and cloud/shaft suppression passed");
        glDeleteProgram(program);
    }

    private static void checkSpatialAa(Path source) throws IOException {
        int program = compile(GL_COMPUTE_SHADER, Files.readString(source));
        bindImages(program, "scene");
        float[] pixels = new float[64];
        for (int row = 0; row < 4; row++) {
            for (int column = 0; column < 4; column++) {
                int offset = (row * 4 + column) * 4;
                int shade = column >= row ? 1 : 0;
                Arrays.fill(pixels, offset, offset + 3, shade);
                pixels[offset + 3] = 1;
            }
        }
        int texture = fixtureTexture(0, 4, pixels);
        float[] result = readShaderOutput(pixels.length);
        float lightEdge = result[(1 * 4 + 1) * 4];
        float darkEdge = result[(2 * 4 + 1) * 4];
        if (!(lightEdge > 0.5f && lightEdge < 1.0f && darkEdge > 0.0f && darkEdge < 0.5f)
            || result[(0 * 4 + 3) * 4] != 1.0f || result[(3 * 4) * 4] != 0.0f) {
            throw new IllegalStateException("Unexpected spatial AA diagonal or flat region");
        }
        if (glGetError() != GL_NO_ERROR) {
            throw new IllegalStateException("Spatial AA OpenGL error");
        }
        System.out.println("Spatial AA readback: diagonal smoothing and flat region preservation passed");
        glDeleteTextures(texture);
        glDeleteProgram(program);
    }

    private static float[] readShaderOutput(int channels) {
        int buffer = glGenBuffers();
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, buffer);
        glBufferData(GL_SHADER_STORAGE_BUFFER, (long) channels * Float.BYTES, GL_DYNAMIC_READ);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, buffer);
        glDispatchCompute(1, 1, 1);
        glMemoryBarrier(GL_BUFFER_UPDATE_BARRIER_BIT);
        float[] result = new float[channels];
        glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, result);
        glDeleteBuffers(buffer);
        return result;
    }

    private static int fixtureTexture(int unit, float[] pixels) {
        return fixtureTexture(unit, pixels.length / 4, pixels);
    }

    private static int fixtureTexture(int unit, int width, float[] pixels) {
        int texture = glGenTextures();
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, pixels.length / (4 * width), 0, GL_RGBA, GL_FLOAT, pixels);
        return texture;
    }

    private static void measure(int size, int[] programs) {
        int[] volumes = new int[3];
        for (int index = 0; index < volumes.length; index++) {
            volumes[index] = glGenTextures();
            glBindTexture(GL_TEXTURE_3D, volumes[index]);
            glTexStorage3D(GL_TEXTURE_3D, 1, GL_RGBA16F, size, size, size);
            glBindImageTexture(index, volumes[index], 0, true, 0, GL_READ_WRITE, GL_RGBA16F);
        }
        for (int sample = 0; sample < WARMUP; sample++) {
            dispatch(size, programs);
        }
        int[] queries = new int[SAMPLES];
        glGenQueries(queries);
        for (int query : queries) {
            glBeginQuery(GL_TIME_ELAPSED, query);
            dispatch(size, programs);
            glEndQuery(GL_TIME_ELAPSED);
        }
        long[] elapsed = new long[SAMPLES];
        for (int index = 0; index < elapsed.length; index++) {
            elapsed[index] = glGetQueryObjectui64(queries[index], GL_QUERY_RESULT);
        }
        Arrays.sort(elapsed);
        checkValues(size, volumes[2]);
        int error = glGetError();
        if (error != GL_NO_ERROR) {
            throw new IllegalStateException("OpenGL error " + error);
        }
        System.out.printf(java.util.Locale.ROOT, "%d,%d,%.4f,%.4f,%.4f,%.2f%n",
            size, SAMPLES, percentile(elapsed, 0.5), percentile(elapsed, 0.95), percentile(elapsed, 0.99),
            volumes.length * 8.0 * size * size * size / (1024 * 1024));
        glDeleteQueries(queries);
        glDeleteTextures(volumes);
    }

    private static void dispatch(int size, int[] programs) {
        for (int program : programs) {
            glUseProgram(program);
            glDispatchCompute(size / 4, size / 4, size / 4);
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_SHADER_STORAGE_BARRIER_BIT);
        }
    }

    private static double percentile(long[] sorted, double fraction) {
        return sorted[(int)Math.ceil(sorted.length * fraction) - 1] / 1_000_000.0;
    }

    private static void checkValues(int size, int texture) {
        FloatBuffer pixels = BufferUtils.createFloatBuffer(size * size * size * 4);
        glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT | GL_BUFFER_UPDATE_BARRIER_BIT);
        glBindTexture(GL_TEXTURE_3D, texture);
        glGetTexImage(GL_TEXTURE_3D, 0, GL_RGBA, GL_FLOAT, pixels);
        int center = size / 2;
        checkCell(pixels, size, center - 8, 0.5625f, 0.5625f, 0.0f);
        checkCell(pixels, size, center - 10, 1.0f, 0.0f, 0.0f);
        checkCell(pixels, size, center - 1, 1.0f, 0.0f, 0.0f);
        checkCell(pixels, size, center, 0.0f, 0.0f, 1.0f);
        checkCell(pixels, size, center + 1, 0.0f, 0.0f, 0.0f);
        if (glGetBufferSubDataSignature() != 0x4c575630) {
            throw new IllegalStateException("Invalid GPU status signature");
        }
    }

    private static int glGetBufferSubDataSignature() {
        int[] signature = new int[1];
        glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, signature);
        return signature[0];
    }

    private static void checkCell(FloatBuffer pixels, int size, int column, float red, float blue, float alpha) {
        int center = size / 2;
        int offset = 4 * ((center * size + center) * size + column);
        if (pixels.get(offset) != red || pixels.get(offset + 1) != 0.0f ||
            pixels.get(offset + 2) != blue || pixels.get(offset + 3) != alpha) {
            throw new IllegalStateException("Unexpected voxel at size " + size + ", column " + column);
        }
    }
}
