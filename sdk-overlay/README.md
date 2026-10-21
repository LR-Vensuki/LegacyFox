# SDK overlay

Headers the iOS 6.1 SDK lacks but Gecko includes. `-isystem` in the
mozconfigs puts this directory after the SDK's own headers in effect only
for files the SDK does not have.

| Header | From | Why it is enough |
|---|---|---|
| `IOKit/` | macOS 10.8 SDK | iOS ships the IOKit framework (in the 6.1 SDK too), just not its headers |
| `IOSurface/` | macOS 10.8 SDK, XPC calls removed | private framework on iOS 6; every function weak-imported, Gecko's IOSurface paths stay unused |
| `VideoToolbox/` | iOS 8.0 SDK | the framework is in the 6.1 SDK without headers; its decoder is the hardware H.264 path |
| `os/log.h`, `os/availability.h` | written here | iOS 10/11 APIs: no-op macros |
| `CoreAudioTypes/` | written here | newer SDKs split `CoreAudio/CoreAudioTypes.h` |
| `crt_externs.h`, `sys/fileport.h` | written here | in libSystem/the kernel, header macOS-only |
| `CoreServices/CoreServices.h` | written here | umbrella over CoreFoundation, MobileCoreServices, CFNetwork |
| `Frameworks/IOSurface.framework/IOSurface.tbd` | generated from the headers | link stub; the real library is in the iOS 6 dyld cache (PrivateFrameworks) |
