// legacyfox_compat: what the engine and Rust's std call that iOS 4-7 lacks.
//
// Linked statically into the app, so on any iOS the app binds to these
// definitions, never to a system symbol that may not exist.

#ifndef LEGACYFOX_COMPAT_H
#define LEGACYFOX_COMPAT_H

#include <stddef.h>
#include <stdint.h>
#include <time.h>
#include <dirent.h>

// C11's static_assert macro: the iOS 6.1 SDK's <assert.h> predates it.
#if !defined(__cplusplus) && !defined(static_assert)
#define static_assert _Static_assert
#endif

// Constants newer SDKs have and the iOS 6.1 SDK does not. Only values: what
// they name is never available at runtime on iOS 4-7, so Gecko only compares
// against them.
#if defined(__APPLE__)
#define kAudioFormatMPEGD_USAC 'usac'
#define kAudioCodecPropertyProgramTargetLevel 'pptl'
#define kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange 'x420'
#define kCVPixelFormatType_420YpCbCr10BiPlanarFullRange 'xf20'
#define kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange 'x422'
#define kCVPixelFormatType_422YpCbCr10BiPlanarFullRange 'xf22'
#define kCVPixelFormatType_ARGB2101010LEPacked 'l10r'
#define kCVPixelFormatType_4444AYpCbCrFloat 'r4fl'
#define kCMVideoCodecType_HEVC 'hvc1'
#define kCMVideoCodecType_AV1 'av01'
#endif

#ifdef __cplusplus
extern "C" {
#endif

// clock_gettime and its clock ids came with iOS 10.
#ifndef CLOCK_REALTIME
typedef int clockid_t;
#define CLOCK_REALTIME 0
#define CLOCK_MONOTONIC_RAW 4
#define CLOCK_MONOTONIC_RAW_APPROX 5
#define CLOCK_MONOTONIC 6
#define CLOCK_UPTIME_RAW 8
#define CLOCK_UPTIME_RAW_APPROX 9
#define CLOCK_PROCESS_CPUTIME_ID 12
#define CLOCK_THREAD_CPUTIME_ID 16
#define LEGACYFOX_COMPAT_CLOCKS 1
#endif
int clock_gettime(clockid_t clock_id, struct timespec *tp);
int clock_getres(clockid_t clock_id, struct timespec *res);
uint64_t clock_gettime_nsec_np(clockid_t clock_id);

// CommonCrypto's random bytes came with iOS 8 (std::sys::random on Apple).
int32_t CCRandomGenerateBytes(void *bytes, size_t count);

// libc++ calls asprintf_l, which <xlocale/_stdio.h> hides when a file asks
// for a stricter POSIX level. Declared here with locale_t's underlying type,
// so it never conflicts with the SDK's own declaration.
#if defined(__APPLE__)
struct _xlocale;
int asprintf_l(char **, struct _xlocale *, const char *, ...);
#endif

// clang emits __sincos_stret for sin+cos pairs when generating code for
// iOS 7+, which LegacyFox does (for thread_local); libSystem has it from 7.
struct legacyfox_sincos { double sinval, cosval; };
struct legacyfox_sincosf { float sinval, cosval; };
struct legacyfox_sincos __sincos_stret(double x);
struct legacyfox_sincosf __sincosf_stret(float x);
// pow(10, x) becomes __exp10 for iOS 7+ too.
double __exp10(double x);
float __exp10f(float x);

// The *at file calls came with iOS 8; Rust's std::fs uses them.
#ifndef AT_FDCWD
#define AT_FDCWD -2
#define AT_EACCESS 0x0010
#define AT_SYMLINK_NOFOLLOW 0x0020
#define AT_SYMLINK_FOLLOW 0x0040
#define AT_REMOVEDIR 0x0080
#endif
struct stat;
int openat(int fd, const char *path, int flags, ...);
int fstatat(int fd, const char *path, struct stat *buf, int flags);
int mkdirat(int fd, const char *path, unsigned short mode);
int unlinkat(int fd, const char *path, int flags);
int renameat(int fromfd, const char *from, int tofd, const char *to);
int linkat(int fd1, const char *name1, int fd2, const char *name2, int flags);
int fchmodat(int fd, const char *path, unsigned short mode, int flags);
DIR *fdopendir(int fd);
// fclonefileat (iOS 10): never clones, callers fall back to copying.
int fclonefileat(int srcfd, int dst_dirfd, const char *dst, uint32_t flags);
// sysdir (iOS 10): enumerates nothing.
unsigned int sysdir_start_search_path_enumeration(unsigned int dir, unsigned int domain_mask);
unsigned int sysdir_get_next_search_path_enumeration(unsigned int state, char *path);

#ifdef __cplusplus
}
#endif

#endif
