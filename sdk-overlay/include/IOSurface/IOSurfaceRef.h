/* LegacyFox SDK overlay: the iOS 6.1 SDK has no IOSurface headers (the
 * framework is private there). The API is macOS 10.8's, under the header
 * name newer SDKs use. Functions are weak: Gecko must not reach IOSurface
 * paths on iOS 4-7, and a missing one resolves to NULL instead of failing
 * to load. */
#ifndef LEGACYFOX_IOSURFACEREF_H
#define LEGACYFOX_IOSURFACEREF_H
#pragma GCC system_header
#include <IOSurface/IOSurfaceAPI.h>
__BEGIN_DECLS
CFDictionaryRef IOSurfaceCopyAllValues(IOSurfaceRef buffer) __attribute__((weak_import));
__END_DECLS
#endif
