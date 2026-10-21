/* LegacyFox SDK overlay: AVSampleBufferDisplayLayer and the CoreMedia /
 * CoreVideo calls Gecko feeds it with are iOS 8 API. Declared weak: on iOS
 * 4-7 the class is nil, so Gecko's isKindOfClass: checks fail and it keeps
 * video in ordinary layers (gfx.core-animation.specialize-video is off).
 * The C functions are visible to C++ too; the class only to Objective-C. */
#ifndef LEGACYFOX_AVSAMPLEBUFFERDISPLAYLAYER_H
#define LEGACYFOX_AVSAMPLEBUFFERDISPLAYLAYER_H
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <IOSurface/IOSurfaceRef.h>

__BEGIN_DECLS
OSStatus CMSampleBufferCreateReadyWithImageBuffer(
    CFAllocatorRef allocator, CVImageBufferRef imageBuffer,
    CMVideoFormatDescriptionRef formatDescription,
    const CMSampleTimingInfo* sampleTiming, CMSampleBufferRef* sampleBufferOut)
    __attribute__((weak_import));
CVReturn CVPixelBufferCreateWithIOSurface(CFAllocatorRef allocator,
                                          IOSurfaceRef surface,
                                          CFDictionaryRef pixelBufferAttributes,
                                          CVPixelBufferRef* pixelBufferOut)
    __attribute__((weak_import));
IOSurfaceRef CVPixelBufferGetIOSurface(CVPixelBufferRef pixelBuffer)
    __attribute__((weak_import));
__END_DECLS

#ifdef __OBJC__
#import <QuartzCore/QuartzCore.h>

typedef NSInteger AVQueuedSampleBufferRenderingStatus;
enum {
  AVQueuedSampleBufferRenderingStatusUnknown = 0,
  AVQueuedSampleBufferRenderingStatusRendering = 1,
  AVQueuedSampleBufferRenderingStatusFailed = 2
};

__attribute__((weak_import))
@interface AVSampleBufferDisplayLayer : CALayer
@property(copy) NSString* videoGravity;
@property(assign) CMTimebaseRef controlTimebase;
@property(readonly) AVQueuedSampleBufferRenderingStatus status;
@property(readonly) BOOL requiresFlushToResumeDecoding;
@property(readonly, getter=isReadyForMoreMediaData) BOOL readyForMoreMediaData;
@property BOOL preventsCapture;
- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)flush;
- (void)flushAndRemoveImage;
@end
#endif

#endif
