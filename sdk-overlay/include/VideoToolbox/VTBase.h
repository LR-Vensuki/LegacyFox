/*
	File:  VTBase.h

	Framework:  VideoToolbox

	Copyright 2013 Apple Inc. All rights reserved.

*/

#ifndef VTBASE_H
#define VTBASE_H

/* LegacyFox SDK overlay: these headers are the iOS 8.0 SDK's. The iOS 6.1
 * SDK's <Availability.h> knows no iOS 7/8, so their availability names are
 * defined here, and everything they mark is weak-imported: VideoToolbox is in
 * iOS 6 (privately), and what it lacks resolves to NULL. */
#include <Availability.h>
#ifndef __IPHONE_7_0
#define __IPHONE_7_0 70000
#endif
#ifndef __IPHONE_8_0
#define __IPHONE_8_0 80000
#endif
#ifndef __MAC_10_9
#define __MAC_10_9 1090
#endif
#ifndef __MAC_10_10
#define __MAC_10_10 101000
#endif
#ifndef __AVAILABILITY_INTERNAL__IPHONE_7_0
#define __AVAILABILITY_INTERNAL__IPHONE_7_0 __attribute__((weak_import))
#endif
#ifndef __AVAILABILITY_INTERNAL__IPHONE_8_0
#define __AVAILABILITY_INTERNAL__IPHONE_8_0 __attribute__((weak_import))
#endif

#include <Availability.h>

#if defined(__cplusplus)
extern "C"
{
#endif

#pragma pack(push, 4)


#if TARGET_OS_IPHONE
#define VT_AVAILABLE_STARTING(_ver) 
#else
#define VT_AVAILABLE_STARTING(_ver) __OSX_AVAILABLE_STARTING(__MAC_##_ver, __IPHONE_NA)
#endif


#pragma pack(pop)

#if defined(__cplusplus)
}
#endif

#endif // VTBASE_H
