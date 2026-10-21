/* LegacyFox SDK overlay: iOS SDKs got a CoreServices umbrella only later;
 * on iOS 6 its parts are CoreFoundation, MobileCoreServices and CFNetwork. */
#ifndef LEGACYFOX_CORESERVICES_H
#define LEGACYFOX_CORESERVICES_H
#include <CoreFoundation/CoreFoundation.h>
#include <MobileCoreServices/MobileCoreServices.h>
#include <CFNetwork/CFNetwork.h>
#endif
