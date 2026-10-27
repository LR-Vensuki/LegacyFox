// Prints what the device's OpenGL ES 2 offers (renderer, limits,
// extensions), for deciding what WebRender could draw on the GPU.
#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#include <stdio.h>

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    {
        EAGLContext *c = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!c || ![EAGLContext setCurrentContext:c]) {
            fprintf(stderr, "no GLES2 context\n");
            return 1;
        }
        EAGLContext *c3 = [[EAGLContext alloc] initWithAPI:(EAGLRenderingAPI)3];
        printf("GLES3: %s\n", c3 ? "yes" : "no");
        printf("vendor: %s\nrenderer: %s\nversion: %s\nglsl: %s\n", glGetString(GL_VENDOR), glGetString(GL_RENDERER),
               glGetString(GL_VERSION), glGetString(GL_SHADING_LANGUAGE_VERSION));
        GLint v[2];
        struct { GLenum e; const char *n; } q[] = {
            {GL_MAX_TEXTURE_SIZE, "max_texture_size"}, {GL_MAX_TEXTURE_IMAGE_UNITS, "max_texture_units"},
            {GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS, "max_vertex_texture_units"},
            {GL_MAX_VERTEX_ATTRIBS, "max_vertex_attribs"}, {GL_MAX_VARYING_VECTORS, "max_varying_vectors"},
            {GL_MAX_VERTEX_UNIFORM_VECTORS, "max_vertex_uniforms"}, {GL_MAX_FRAGMENT_UNIFORM_VECTORS, "max_fragment_uniforms"},
            {GL_MAX_RENDERBUFFER_SIZE, "max_renderbuffer"}};
        for (unsigned i = 0; i < sizeof(q) / sizeof(q[0]); i++) {
            glGetIntegerv(q[i].e, v);
            printf("%s: %d\n", q[i].n, v[0]);
        }
        printf("extensions:\n");
        const char *ext = (const char *)glGetString(GL_EXTENSIONS);
        for (const char *p = ext; p && *p; p++)
            putchar(*p == ' ' ? '\n' : *p);
        printf("\n");
    }
    [pool release];
    return 0;
}
