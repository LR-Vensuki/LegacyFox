#include "legacyfox_compat.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

static mach_timebase_info_data_t timebase;

static uint64_t mach_to_ns(uint64_t t) {
    if (!timebase.denom)
        mach_timebase_info(&timebase);
    // split to avoid overflow: devices run for weeks at 24 MHz ticks
    return t / timebase.denom * timebase.numer + t % timebase.denom * timebase.numer / timebase.denom;
}

static void ns_to_timespec(uint64_t ns, struct timespec *tp) {
    tp->tv_sec = (time_t)(ns / 1000000000ULL);
    tp->tv_nsec = (long)(ns % 1000000000ULL);
}

int clock_gettime(clockid_t clock_id, struct timespec *tp) {
    if (!tp) {
        errno = EFAULT;
        return -1;
    }
    switch (clock_id) {
    case CLOCK_REALTIME: {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        tp->tv_sec = tv.tv_sec;
        tp->tv_nsec = tv.tv_usec * 1000;
        return 0;
    }
    // mach_absolute_time stops in sleep: that is the uptime clocks exactly,
    // and close enough for the monotonic ones (they only need to not go back).
    case CLOCK_MONOTONIC:
    case CLOCK_MONOTONIC_RAW:
    case CLOCK_MONOTONIC_RAW_APPROX:
    case CLOCK_UPTIME_RAW:
    case CLOCK_UPTIME_RAW_APPROX:
        ns_to_timespec(mach_to_ns(mach_absolute_time()), tp);
        return 0;
    case CLOCK_PROCESS_CPUTIME_ID: {
        struct rusage ru;
        if (getrusage(RUSAGE_SELF, &ru))
            return -1;
        uint64_t us = (uint64_t)(ru.ru_utime.tv_sec + ru.ru_stime.tv_sec) * 1000000ULL
                    + ru.ru_utime.tv_usec + ru.ru_stime.tv_usec;
        ns_to_timespec(us * 1000, tp);
        return 0;
    }
    case CLOCK_THREAD_CPUTIME_ID: {
        thread_basic_info_data_t info;
        mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
        mach_port_t thread = pthread_mach_thread_np(pthread_self());
        if (thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&info, &count) != KERN_SUCCESS) {
            errno = EINVAL;
            return -1;
        }
        uint64_t us = (uint64_t)(info.user_time.seconds + info.system_time.seconds) * 1000000ULL
                    + info.user_time.microseconds + info.system_time.microseconds;
        ns_to_timespec(us * 1000, tp);
        return 0;
    }
    }
    errno = EINVAL;
    return -1;
}

int clock_getres(clockid_t clock_id, struct timespec *res) {
    struct timespec now;
    if (clock_gettime(clock_id, &now))
        return -1;
    if (res) {
        res->tv_sec = 0;
        res->tv_nsec = clock_id == CLOCK_REALTIME ? 1000 : 1;
    }
    return 0;
}

uint64_t clock_gettime_nsec_np(clockid_t clock_id) {
    struct timespec ts;
    if (clock_gettime(clock_id, &ts))
        return 0;
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

int32_t CCRandomGenerateBytes(void *bytes, size_t count) {
    static int fd = -1;
    if (fd < 0) {
        int opened = open("/dev/urandom", O_RDONLY);
        if (opened < 0)
            return -1;
        if (!__sync_bool_compare_and_swap(&fd, -1, opened))
            close(opened);
    }
    unsigned char *p = bytes;
    while (count) {
        ssize_t n = read(fd, p, count);
        if (n < 0 && errno == EINTR)
            continue;
        if (n <= 0)
            return -1;
        p += n;
        count -= (size_t)n;
    }
    return 0; // kCCSuccess
}

// ---- *at file calls ---------------------------------------------------------
// Relative to a directory fd: the fd's path (F_GETPATH) joined with the
// relative one. Not atomic against renames of that directory, which none of
// the callers rely on.

#include <dirent.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static const char *at_path(int fd, const char *path, char buf[PATH_MAX]) {
    if (fd == AT_FDCWD || !path || path[0] == '/')
        return path;
    char dir[PATH_MAX];
    if (fcntl(fd, F_GETPATH, dir) == -1)
        return NULL;
    if (snprintf(buf, PATH_MAX, "%s/%s", dir, path) >= PATH_MAX) {
        errno = ENAMETOOLONG;
        return NULL;
    }
    return buf;
}

int openat(int fd, const char *path, int flags, ...) {
    char buf[PATH_MAX];
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    const char *p = at_path(fd, path, buf);
    return p ? open(p, flags, mode) : -1;
}

int fstatat(int fd, const char *path, struct stat *st, int flags) {
    char buf[PATH_MAX];
    const char *p = at_path(fd, path, buf);
    if (!p)
        return -1;
    return (flags & AT_SYMLINK_NOFOLLOW) ? lstat(p, st) : stat(p, st);
}

int mkdirat(int fd, const char *path, unsigned short mode) {
    char buf[PATH_MAX];
    const char *p = at_path(fd, path, buf);
    return p ? mkdir(p, mode) : -1;
}

int unlinkat(int fd, const char *path, int flags) {
    char buf[PATH_MAX];
    const char *p = at_path(fd, path, buf);
    if (!p)
        return -1;
    return (flags & AT_REMOVEDIR) ? rmdir(p) : unlink(p);
}

int renameat(int fromfd, const char *from, int tofd, const char *to) {
    char b1[PATH_MAX], b2[PATH_MAX];
    const char *p1 = at_path(fromfd, from, b1), *p2 = at_path(tofd, to, b2);
    return p1 && p2 ? rename(p1, p2) : -1;
}

int linkat(int fd1, const char *name1, int fd2, const char *name2, int flags) {
    char b1[PATH_MAX], b2[PATH_MAX];
    const char *p1 = at_path(fd1, name1, b1), *p2 = at_path(fd2, name2, b2);
    return p1 && p2 ? link(p1, p2) : -1;
}

int fchmodat(int fd, const char *path, unsigned short mode, int flags) {
    char buf[PATH_MAX];
    const char *p = at_path(fd, path, buf);
    if (!p)
        return -1;
    // no lchmod before iOS 8 either: a symlink keeps its mode
    if (flags & AT_SYMLINK_NOFOLLOW) {
        struct stat st;
        if (lstat(p, &st) == 0 && S_ISLNK(st.st_mode)) {
            errno = EOPNOTSUPP;
            return -1;
        }
    }
    return chmod(p, mode);
}

DIR *fdopendir(int fd) {
    char dir[PATH_MAX];
    if (fcntl(fd, F_GETPATH, dir) == -1)
        return NULL;
    DIR *d = opendir(dir);
    if (d)
        close(fd); // fdopendir owns the fd; the DIR has its own
    return d;
}

int fclonefileat(int srcfd, int dst_dirfd, const char *dst, uint32_t flags) {
    errno = ENOTSUP;
    return -1;
}

unsigned int sysdir_start_search_path_enumeration(unsigned int dir, unsigned int domain_mask) {
    return 0;
}

unsigned int sysdir_get_next_search_path_enumeration(unsigned int state, char *path) {
    return 0;
}

// ---- __sincos_stret ---------------------------------------------------------
#include <math.h>

struct legacyfox_sincos __sincos_stret(double x) {
    struct legacyfox_sincos r = { sin(x), cos(x) };
    return r;
}

struct legacyfox_sincosf __sincosf_stret(float x) {
    struct legacyfox_sincosf r = { sinf(x), cosf(x) };
    return r;
}

double __exp10(double x) {
    return pow(10.0, x);
}

float __exp10f(float x) {
    return powf(10.0f, x);
}

#include <sys/socket.h>
#include <sys/uio.h>

// ---- _tlv_atexit ------------------------------------------------------------
// clang registers destructors of thread_local objects here even with
// -femulated-tls; dyld provides it only from iOS 8. They are not run: the
// objects live in emulated-TLS storage that libclang_rt frees from its own
// pthread key destructor, in no fixed order with any of ours, so running them
// at thread exit would touch freed memory. A thread's thread_locals leak.

void _tlv_atexit(void (*func)(void *), void *obj) {
    (void)func;
    (void)obj;
}

// ---- sendmsg_x / recvmsg_x ------------------------------------------------
// Batched socket calls (iOS 9+), used by quinn-udp for HTTP/3. One message
// at a time with the plain calls.

struct msghdr_x {
    void *msg_name;
    socklen_t msg_namelen;
    struct iovec *msg_iov;
    int msg_iovlen;
    void *msg_control;
    socklen_t msg_controllen;
    int msg_flags;
    size_t msg_datalen;
};

ssize_t sendmsg_x(int s, const struct msghdr_x *msgp, unsigned int cnt, int flags) {
    unsigned int i;
    for (i = 0; i < cnt; i++) {
        struct msghdr m = {msgp[i].msg_name, msgp[i].msg_namelen, msgp[i].msg_iov,
                           msgp[i].msg_iovlen, msgp[i].msg_control,
                           msgp[i].msg_controllen, 0};
        if (sendmsg(s, &m, flags) < 0)
            return i ? (ssize_t)i : -1;
    }
    return i;
}

ssize_t recvmsg_x(int s, struct msghdr_x *msgp, unsigned int cnt, int flags) {
    unsigned int i;
    for (i = 0; i < cnt; i++) {
        struct msghdr m = {msgp[i].msg_name, msgp[i].msg_namelen, msgp[i].msg_iov,
                           msgp[i].msg_iovlen, msgp[i].msg_control,
                           msgp[i].msg_controllen, 0};
        ssize_t n = recvmsg(s, &m, i ? (flags | MSG_DONTWAIT) : flags);
        if (n < 0) {
            if (i && (errno == EAGAIN || errno == EWOULDBLOCK))
                break;
            return i ? (ssize_t)i : -1;
        }
        msgp[i].msg_namelen = m.msg_namelen;
        msgp[i].msg_controllen = m.msg_controllen;
        msgp[i].msg_flags = m.msg_flags;
        msgp[i].msg_datalen = (size_t)n;
    }
    return i;
}

