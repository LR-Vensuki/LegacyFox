// screenshot: PNG of the device screen for jailbroken iOS 4-7 without the
// developer disk image, through CoreAnimation's render server.
//   screenshot /path/out.png
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <IOSurface/IOSurfaceRef.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void CARenderServerRenderDisplay(int port, CFStringRef display, IOSurfaceRef surface,
                                        int x, int y);
extern CGImageRef UIGetScreenImage(void) __attribute__((weak_import));

static CFNumberRef num(int v) { return CFNumberCreate(NULL, kCFNumberIntType, &v); }

int main(int argc, char **argv) {
    const char *out = argc > 1 ? argv[1] : "/tmp/screen.png";
    // The iPad 2 panel is 1024x768 in its own (landscape) orientation; the
    // render server wants a square surface at least that wide.
    int pw = argc > 3 ? atoi(argv[2]) : 1024, ph = argc > 3 ? atoi(argv[3]) : 768;
    int w = pw > ph ? pw : ph, h = w;
    int bpe = 4, bpr = w * bpe, fmt = 'BGRA';
    const void *k[] = {kIOSurfaceIsGlobal, kIOSurfaceWidth, kIOSurfaceHeight, kIOSurfaceBytesPerElement,
                       kIOSurfaceBytesPerRow, kIOSurfacePixelFormat, kIOSurfaceAllocSize};
    const void *v[] = {kCFBooleanTrue, num(w), num(h), num(bpe), num(bpr), num(fmt), num(bpr * h)};
    CFDictionaryRef props = CFDictionaryCreate(NULL, k, v, 7, &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    IOSurfaceRef surface = IOSurfaceCreate(props);
    if (!surface) { fprintf(stderr, "no IOSurface\n"); return 1; }
    IOSurfaceLock(surface, 0, NULL);
    CARenderServerRenderDisplay(0, CFSTR("LCD"), surface, 0, 0);
    void *base = IOSurfaceGetBaseAddress(surface);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(base, w, h, 8, bpr, cs,
                                             kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGImageRef full = CGBitmapContextCreateImage(ctx);
    IOSurfaceUnlock(surface, 0, NULL);
    // Crop to the panel and turn it to portrait, the way the device is held.
    CGImageRef panel = CGImageCreateWithImageInRect(full, CGRectMake(0, 0, pw, ph));
    CGContextRef rot = CGBitmapContextCreate(NULL, ph, pw, 8, 0, cs,
                                             kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGContextTranslateCTM(rot, ph, 0);
    CGContextRotateCTM(rot, M_PI_2);
    CGContextDrawImage(rot, CGRectMake(0, 0, pw, ph), panel);
    CGImageRef img = CGBitmapContextCreateImage(rot);
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)out, strlen(out), false);
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL(url, CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImage(dest, img, NULL);
    if (!CGImageDestinationFinalize(dest)) { fprintf(stderr, "write failed\n"); return 1; }
    printf("%s %dx%d\n", out, ph, pw);
    return 0;
}
