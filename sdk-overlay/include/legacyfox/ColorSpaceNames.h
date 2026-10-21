/* LegacyFox: color space and YCbCr attachment names newer SDKs export. Gecko
 * only tags IOSurfaces with them, so their string values are enough; iOS 4-7
 * ignore tags they do not know. */
#ifndef LEGACYFOX_COLORSPACENAMES_H
#define LEGACYFOX_COLORSPACENAMES_H
#include <CoreFoundation/CoreFoundation.h>
#define kCGColorSpaceSRGB CFSTR("kCGColorSpaceSRGB")
#define kCGColorSpaceDisplayP3 CFSTR("kCGColorSpaceDisplayP3")
#define kCGColorSpaceITUR_709 CFSTR("kCGColorSpaceITUR_709")
#define kCGColorSpaceITUR_2020 CFSTR("kCGColorSpaceITUR_2020")
#define kCVImageBufferYCbCrMatrix_ITU_R_2020 CFSTR("ITU_R_2020")
#define kCVImageBufferColorPrimaries_ITU_R_2020 CFSTR("ITU_R_2020")
/* HDR metadata and VideoToolbox keys (iOS 8-11), by value. */
#define kCVImageBufferMasteringDisplayColorVolumeKey CFSTR("MasteringDisplayColorVolume")
#define kCVImageBufferContentLightLevelInfoKey CFSTR("ContentLightLevelInfo")
#define kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder \
  CFSTR("UsingHardwareAcceleratedVideoDecoder")
#define kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder \
  CFSTR("EnableHardwareAcceleratedVideoDecoder")
#endif
