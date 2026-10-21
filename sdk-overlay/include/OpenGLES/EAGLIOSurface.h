/* LegacyFox SDK overlay: EAGLContext's IOSurface texture call is public from
 * iOS 11 (private before). Declared so Gecko compiles; LegacyFox composites
 * with software WebRender into IOSurface-backed CALayers, not through it. */
#ifndef LEGACYFOX_EAGLIOSURFACE_H
#define LEGACYFOX_EAGLIOSURFACE_H
#import <OpenGLES/EAGL.h>
#include <IOSurface/IOSurfaceRef.h>
@interface EAGLContext (LegacyFoxIOSurface)
- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface
                   target:(NSUInteger)target
           internalFormat:(NSUInteger)internalFormat
                    width:(uint32_t)width
                   height:(uint32_t)height
                   format:(NSUInteger)format
                     type:(NSUInteger)type
                    plane:(uint32_t)plane;
@end
#endif
