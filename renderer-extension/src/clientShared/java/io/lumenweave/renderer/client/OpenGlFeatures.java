package io.lumenweave.renderer.client;

import org.lwjgl.opengl.GLCapabilities;

public final class OpenGlFeatures {
    public static boolean seedBridge(GLCapabilities capabilities) {
        return capabilities.OpenGL45 || (
            capabilities.GL_ARB_direct_state_access
            && capabilities.GL_ARB_clear_texture
            && capabilities.GL_ARB_compute_shader
            && capabilities.GL_ARB_shader_storage_buffer_object
            && capabilities.GL_ARB_shader_image_load_store
        );
    }

    private OpenGlFeatures() {}
}
