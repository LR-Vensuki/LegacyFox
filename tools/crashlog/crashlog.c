// crashlog.dylib: on a fatal signal, print where it happened, for devices
// without a debugger. Load it with DYLD_INSERT_LIBRARIES=crashlog.dylib.
//
// Prints the faulting address, pc/lr/sp and a frame-pointer walk, each as
// image+offset (dladdr), ready for atos/llvm-symbolizer on SuperPC.

#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/ucontext.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>

static void where(const char *what, uintptr_t addr) {
    Dl_info info;
    if (addr && dladdr((void *)addr, &info) && info.dli_fname) {
        const char *name = strrchr(info.dli_fname, '/');
        name = name ? name + 1 : info.dli_fname;
        fprintf(stderr, "  %-4s 0x%08lx  %s+0x%lx  %s\n", what, (unsigned long)addr, name,
                (unsigned long)(addr - (uintptr_t)info.dli_fbase),
                info.dli_sname ? info.dli_sname : "");
    } else {
        fprintf(stderr, "  %-4s 0x%08lx\n", what, (unsigned long)addr);
    }
}

static pthread_t main_thread;

static void dump_frames(ucontext_t *uc) {
#if defined(__arm__)
    struct __darwin_arm_thread_state *ts = &uc->uc_mcontext->__ss;
    where("pc", ts->__pc);
    where("lr", ts->__lr);
    uintptr_t *fp = (uintptr_t *)ts->__r[7];
    for (int i = 0; fp && i < 60; i++) {
        uintptr_t ret = fp[1];
        if (!ret)
            break;
        where("ret", ret);
        uintptr_t *next = (uintptr_t *)fp[0];
        if (next <= fp)
            break;
        fp = next;
    }
#endif
}

// SIGUSR1 (kill -USR1 <pid>): where the main thread is, for hangs.
static void sample(int sig, siginfo_t *si, void *ctx) {
    if (!pthread_equal(pthread_self(), main_thread)) {
        pthread_kill(main_thread, SIGUSR1);
        return;
    }
    fprintf(stderr, "\n*** crashlog: main thread sample\n");
    dump_frames(ctx);
}

// SIGUSR2: every thread's stack, for hangs that are not on the main thread.
static void walk(uintptr_t pc, uintptr_t lr, uintptr_t fp0) {
    where("pc", pc);
    where("lr", lr);
    uintptr_t *fp = (uintptr_t *)fp0;
    for (int i = 0; fp && i < 40; i++) {
        uintptr_t ret = fp[1];
        if (!ret)
            break;
        where("ret", ret);
        uintptr_t *next = (uintptr_t *)fp[0];
        if (next <= fp)
            break;
        fp = next;
    }
}

static void sample_all(int sig, siginfo_t *si, void *ctx) {
#if defined(__arm__)
    thread_act_array_t threads;
    mach_msg_type_number_t count;
    mach_port_t self = mach_thread_self();
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS)
        return;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        char name[64] = "";
        if (threads[i] == self) {
            fprintf(stderr, "\n*** thread %u (this one)\n", i);
            continue;
        }
        thread_suspend(threads[i]);
        arm_thread_state_t st;
        mach_msg_type_number_t n = ARM_THREAD_STATE_COUNT;
        if (thread_get_state(threads[i], ARM_THREAD_STATE, (thread_state_t)&st, &n) == KERN_SUCCESS) {
            pthread_t pt = pthread_from_mach_thread_np(threads[i]);
            if (pt)
                pthread_getname_np(pt, name, sizeof(name));
            fprintf(stderr, "\n*** thread %u %s\n", i, name);
            walk(st.__pc, st.__lr, st.__r[7]);
        }
        thread_resume(threads[i]);
    }
#endif
}

static void handler(int sig, siginfo_t *si, void *ctx) {
    ucontext_t *uc = ctx;
    fprintf(stderr, "\n*** crashlog: signal %d at address %p\n", sig, si->si_addr);
#if defined(__arm__)
    struct __darwin_arm_thread_state *ts = &uc->uc_mcontext->__ss;
    where("pc", ts->__pc);
    where("lr", ts->__lr);
    fprintf(stderr, "  sp   0x%08x  r7 0x%08x\n", ts->__sp, ts->__r[7]);
    for (int i = 0; i < 13; i++)
        fprintf(stderr, "  r%-2d 0x%08x%s", i, ts->__r[i], i % 4 == 3 ? "\n" : "");
    fprintf(stderr, "\n  frames:\n");
    uintptr_t *fp = (uintptr_t *)ts->__r[7];
    for (int i = 0; fp && i < 40; i++) {
        uintptr_t ret = fp[1];
        if (!ret)
            break;
        where("ret", ret);
        uintptr_t *next = (uintptr_t *)fp[0];
        if (next <= fp)
            break;
        fp = next;
    }
#endif
    fprintf(stderr, "  images:\n");
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (strstr(n, "/System/") || strstr(n, "/usr/lib/"))
            continue;
        fprintf(stderr, "    %p %s\n", (void *)_dyld_get_image_header(i), n);
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

// SIGWINCH (kill -WINCH <pid>): the address space by VM tag, and every
// region of 4 MB or more, for out-of-memory hunts.
static void vmmap(int sig) {
    vm_size_t by_tag[256] = { 0 }, resident_by_tag[256] = { 0 };
    vm_address_t addr = 0;
    vm_size_t total = 0;
    fprintf(stderr, "\n*** crashlog: address space\n");
    // Only the app's own part: the shared cache above 0x30000000 is the
    // same for every process.
    while (addr < 0x30000000) {
        vm_size_t size = 0;
        natural_t depth = 0;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (vm_region_recurse_64(mach_task_self(), &addr, &size, &depth,
                                 (vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS)
            break;
        if (info.is_submap) {
            depth++;
            continue;
        }
        by_tag[info.user_tag & 0xff] += size;
        resident_by_tag[info.user_tag & 0xff] += (vm_size_t)info.pages_resident * 4096;
        total += size;
        if (size >= (4 << 20) && addr < 0x30000000) {
            Dl_info dl;
            const char *name = info.protection && dladdr((void *)addr, &dl) && dl.dli_fname ? dl.dli_fname : "";
            fprintf(stderr, "  %08lx-%08lx %6lu KB tag %3u prot %d/%d res %5u KB %s\n",
                    (unsigned long)addr, (unsigned long)(addr + size), (unsigned long)(size >> 10),
                    info.user_tag, info.protection, info.max_protection,
                    info.pages_resident * 4, name);
        }
        addr += size;
    }
    for (int t = 0; t < 256; t++)
        if (by_tag[t])
            fprintf(stderr, "  tag %3d: %6lu KB virtual, %6lu KB resident\n", t,
                    (unsigned long)(by_tag[t] >> 10), (unsigned long)(resident_by_tag[t] >> 10));
    fprintf(stderr, "  total: %lu MB\n", (unsigned long)(total >> 20));
}

// LF_TRACE_MMAP: who maps 4 MB or more at once, with the caller's frames.
// The app loads this library with dlopen, where interposing does not work,
// so mmap is rebound in every image's symbol pointers (as fishhook does).
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
static void *(*real_mmap)(void *, size_t, int, int, int, off_t);
static void *traced_mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off) {
    void *p = real_mmap(addr, len, prot, flags, fd, off);
    const char *trace = getenv("LF_TRACE_MMAP");
    // LF_TRACE_MMAP=1: files only; 2: anonymous memory too.
    if (trace && len >= (4 << 20) && (fd >= 0 || trace[0] == '2')) {
        char path[1024] = "";
        fcntl(fd, F_GETPATH, path);
        fprintf(stderr, "\n*** crashlog: mmap %lu KB of %s\n", (unsigned long)(len >> 10), path);
        uintptr_t *fp = __builtin_frame_address(0);
        for (int i = 0; fp && i < 80; i++) {
            uintptr_t ret = fp[1];
            if (!ret)
                break;
            where("ret", ret);
            uintptr_t *next = (uintptr_t *)fp[0];
            if (next <= fp)
                break;
            fp = next;
        }
    }
    return p;
}

static int rebound;
static void rebind_mmap(const struct mach_header *mh, intptr_t slide) {
    const struct segment_command *linkedit = NULL, *seg;
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysymtab = NULL;
    uintptr_t cur = (uintptr_t)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++, cur += ((const struct load_command *)cur)->cmdsize) {
        const struct load_command *lc = (const struct load_command *)cur;
        if (lc->cmd == LC_SEGMENT && !strcmp(((const struct segment_command *)lc)->segname, SEG_LINKEDIT))
            linkedit = (const struct segment_command *)lc;
        else if (lc->cmd == LC_SYMTAB)
            symtab = (const struct symtab_command *)lc;
        else if (lc->cmd == LC_DYSYMTAB)
            dysymtab = (const struct dysymtab_command *)lc;
    }
    if (!linkedit || !symtab || !dysymtab || !dysymtab->nindirectsyms)
        return;
    uintptr_t base = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    const struct nlist *syms = (const struct nlist *)(base + symtab->symoff);
    const char *strs = (const char *)(base + symtab->stroff);
    const uint32_t *indirect = (const uint32_t *)(base + dysymtab->indirectsymoff);
    cur = (uintptr_t)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++, cur += ((const struct load_command *)cur)->cmdsize) {
        seg = (const struct segment_command *)cur;
        if (seg->cmd != LC_SEGMENT || strcmp(seg->segname, SEG_DATA))
            continue;
        const struct section *sect = (const struct section *)(seg + 1);
        for (uint32_t j = 0; j < seg->nsects; j++, sect++) {
            uint32_t type = sect->flags & SECTION_TYPE;
            if (type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS)
                continue;
            void **ptrs = (void **)((uintptr_t)slide + sect->addr);
            for (uint32_t k = 0; k < sect->size / sizeof(void *); k++) {
                uint32_t sym = indirect[sect->reserved1 + k];
                if (sym == INDIRECT_SYMBOL_ABS || sym == INDIRECT_SYMBOL_LOCAL ||
                    sym == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS))
                    continue;
                if (!strcmp(strs + syms[sym].n_un.n_strx, "_mmap")) {
                    ptrs[k] = (void *)traced_mmap;
                    rebound++;
                }
            }
        }
    }
}

__attribute__((constructor)) static void install(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = handler;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
    static char altstack[65536];
    stack_t ss = { .ss_sp = altstack, .ss_size = sizeof(altstack), .ss_flags = 0 };
    sigaltstack(&ss, NULL);
    int sigs[] = { SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT, SIGTRAP };
    for (unsigned i = 0; i < sizeof(sigs) / sizeof(sigs[0]); i++)
        sigaction(sigs[i], &sa, NULL);
    main_thread = pthread_self();
    struct sigaction su;
    memset(&su, 0, sizeof(su));
    su.sa_sigaction = sample;
    su.sa_flags = SA_SIGINFO | SA_RESTART;
    sigaction(SIGUSR1, &su, NULL);
    su.sa_sigaction = sample_all;
    sigaction(SIGUSR2, &su, NULL);
    signal(SIGWINCH, vmmap);
    real_mmap = dlsym(RTLD_DEFAULT, "mmap");
    _dyld_register_func_for_add_image(rebind_mmap);
    if (getenv("LF_TRACE_MMAP"))
        fprintf(stderr, "crashlog: mmap rebound in %d places\n", rebound);
}
