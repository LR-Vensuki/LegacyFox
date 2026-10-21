// Apple-framework symbols newer than iOS 6 that Gecko's Rust crates reference
// directly, so a header trick is not enough. Each one does the least that
// keeps its caller correct. (libSystem ones are in legacyfox_compat.c.)

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <Security/Security.h>

// ---- Metal ------------------------------------------------------------------
// wgpu's Metal backend asks for a device; there is none before iOS 8.
void *MTLCreateSystemDefaultDevice(void) {
    return NULL;
}

// ---- CoreText ---------------------------------------------------------------
// The core-text crate calls this iOS 13 function; done with iOS 4.1 calls.
CTFontDescriptorRef CTFontManagerCreateFontDescriptorFromData(CFDataRef data) {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    if (!provider)
        return NULL;
    CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (!cgFont)
        return NULL;
    CTFontManagerRegisterGraphicsFont(cgFont, NULL);
    CTFontRef font = CTFontCreateWithGraphicsFont(cgFont, 0, NULL, NULL);
    CGFontRelease(cgFont);
    if (!font)
        return NULL;
    CTFontDescriptorRef desc = CTFontCopyFontDescriptor(font);
    CFRelease(font);
    return desc;
}

// ---- Security ---------------------------------------------------------------
// osclientcerts (TLS client certificates from the OS keychain) uses the
// iOS 10 SecKey API. Without it there are simply no OS client certificates.
const CFStringRef kSecAttrKeyTypeECSECPrimeRandom = CFSTR("73");
const CFStringRef kSecKeyAlgorithmRSASignatureRaw = CFSTR("algid:sign:RSA:raw");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15Raw = CFSTR("algid:sign:RSA:digest-PKCS1v15");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1 = CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA1");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256 = CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA256");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384 = CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA384");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512 = CFSTR("algid:sign:RSA:digest-PKCS1v15:SHA512");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA1 = CFSTR("algid:sign:ECDSA:digest-X962:SHA1");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA256 = CFSTR("algid:sign:ECDSA:digest-X962:SHA256");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA384 = CFSTR("algid:sign:ECDSA:digest-X962:SHA384");
const CFStringRef kSecKeyAlgorithmECDSASignatureDigestX962SHA512 = CFSTR("algid:sign:ECDSA:digest-X962:SHA512");

CFDictionaryRef SecKeyCopyAttributes(SecKeyRef key) {
    (void)key;
    return NULL;
}

CFDataRef SecKeyCopyExternalRepresentation(SecKeyRef key, CFErrorRef *error) {
    (void)key;
    if (error)
        *error = NULL;
    return NULL;
}

CFDataRef SecKeyCreateSignature(SecKeyRef key, CFStringRef algorithm,
                                CFDataRef dataToSign, CFErrorRef *error) {
    (void)key;
    (void)algorithm;
    (void)dataToSign;
    if (error)
        *error = NULL;
    return NULL;
}

OSStatus SecTrustSetNetworkFetchAllowed(SecTrustRef trust, Boolean allowFetch) {
    (void)trust;
    (void)allowFetch;
    return 0;  // errSecSuccess: iOS 6 decides on its own
}

// ---- Objective-C runtime entry points from iOS 12-14 ----------------------
// The objc2 Rust crates call these directly; each is a message send.
#include <objc/message.h>
#include <objc/runtime.h>

typedef id (*lf_msg_id)(id, SEL);
typedef BOOL (*lf_msg_bool)(id, SEL, ...);

id objc_alloc(Class cls) {
    return cls ? ((lf_msg_id)objc_msgSend)((id)cls, sel_registerName("alloc")) : nil;
}

id objc_alloc_init(Class cls) {
    id obj = objc_alloc(cls);
    return obj ? ((lf_msg_id)objc_msgSend)(obj, sel_registerName("init")) : nil;
}

id objc_opt_new(Class cls) {
    return cls ? ((lf_msg_id)objc_msgSend)((id)cls, sel_registerName("new")) : nil;
}

Class objc_opt_class(id obj) {
    return obj ? (Class)((lf_msg_id)objc_msgSend)(obj, sel_registerName("class")) : Nil;
}

BOOL objc_opt_isKindOfClass(id obj, Class cls) {
    return obj ? ((lf_msg_bool)objc_msgSend)(obj, sel_registerName("isKindOfClass:"), cls) : NO;
}

BOOL objc_opt_respondsToSelector(id obj, SEL sel) {
    return obj ? ((lf_msg_bool)objc_msgSend)(obj, sel_registerName("respondsToSelector:"), sel) : NO;
}
