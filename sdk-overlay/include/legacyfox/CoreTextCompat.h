/* LegacyFox: CoreText font-manager calls from iOS 13+, done with what iOS
 * 4.1+ has. Include after <CoreText/CoreText.h>; the names below then refer
 * to these replacements. */
#ifndef LEGACYFOX_CORETEXTCOMPAT_H
#define LEGACYFOX_CORETEXTCOMPAT_H
#include <CoreText/CoreText.h>
#include <CoreGraphics/CoreGraphics.h>
#include <objc/message.h>
#include <objc/runtime.h>

/* Never posted before iOS 13; observers simply never hear it. */
#define kCTFontManagerRegisteredFontsChangedNotification \
  CFSTR("LegacyFoxRegisteredFontsChangedNotification")

static inline CTFontDescriptorRef LegacyFoxDescriptorFromProvider(
    CGDataProviderRef provider, bool registerFont) {
  if (!provider) {
    return NULL;
  }
  CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
  if (!cgFont) {
    return NULL;
  }
  if (registerFont) {
    /* a descriptor finds the font again by name only once it is registered */
    CTFontManagerRegisterGraphicsFont(cgFont, NULL);
  }
  CTFontRef font = CTFontCreateWithGraphicsFont(cgFont, 0, NULL, NULL);
  CGFontRelease(cgFont);
  if (!font) {
    return NULL;
  }
  CTFontDescriptorRef desc = CTFontCopyFontDescriptor(font);
  CFRelease(font);
  return desc;
}

static inline CTFontDescriptorRef LegacyFoxCreateFontDescriptorFromData(
    CFDataRef data) {
  CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
  CTFontDescriptorRef desc = LegacyFoxDescriptorFromProvider(provider, true);
  if (provider) {
    CGDataProviderRelease(provider);
  }
  return desc;
}
#define CTFontManagerCreateFontDescriptorFromData \
  LegacyFoxCreateFontDescriptorFromData

static inline CFArrayRef LegacyFoxCreateFontDescriptorsFromURL(CFURLRef url) {
  CGDataProviderRef provider = CGDataProviderCreateWithURL(url);
  CTFontDescriptorRef desc = LegacyFoxDescriptorFromProvider(provider, false);
  if (provider) {
    CGDataProviderRelease(provider);
  }
  if (!desc) {
    return NULL;
  }
  CFArrayRef array =
      CFArrayCreate(kCFAllocatorDefault, (const void**)&desc, 1,
                    &kCFTypeArrayCallBacks);
  CFRelease(desc);
  return array;
}
#define CTFontManagerCreateFontDescriptorsFromURL \
  LegacyFoxCreateFontDescriptorsFromURL

static inline void LegacyFoxRegisterFontURLs(CFArrayRef urls,
                                             CTFontManagerScope scope,
                                             bool enabled, void* handler) {
  (void)enabled;
  (void)handler;
  for (CFIndex i = 0; i < CFArrayGetCount(urls); i++) {
    CTFontManagerRegisterFontsForURL((CFURLRef)CFArrayGetValueAtIndex(urls, i),
                                     scope, NULL);
  }
}
#define CTFontManagerRegisterFontURLs LegacyFoxRegisterFontURLs

/* Family names of every installed font, sorted, without duplicates.
 * UIFont's list comes from the system font cache; asking CoreText for every
 * font's descriptor instead maps every font file (100+ MB of CJK fonts) into
 * the app's address space. */
static inline CFArrayRef LegacyFoxCopyAvailableFontFamilyNames(void) {
  typedef CFArrayRef (*FamilyNamesFn)(id, SEL);
  CFArrayRef families = ((FamilyNamesFn)objc_msgSend)(
      (id)objc_getClass("UIFont"), sel_registerName("familyNames"));
  CFMutableArrayRef names =
      families ? CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, families)
               : CFArrayCreateMutable(kCFAllocatorDefault, 0,
                                      &kCFTypeArrayCallBacks);
  CFArraySortValues(names, CFRangeMake(0, CFArrayGetCount(names)),
                    (CFComparatorFunction)CFStringCompare, NULL);
  return names;
}
#define CTFontManagerCopyAvailableFontFamilyNames \
  LegacyFoxCopyAvailableFontFamilyNames

#endif
