/* LegacyFox SDK overlay: the iOS 6.1 SDK keeps the IOSurface pixel buffer
 * key in CVPixelBuffer.h and has no header of this name. */
#include <CoreVideo/CVPixelBuffer.h>
#include <IOSurface/IOSurfaceRef.h>
#include <legacyfox/AVSampleBufferDisplayLayer.h>
