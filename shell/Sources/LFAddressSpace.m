#import "LFAddressSpace.h"
#include <malloc/malloc.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <sys/mman.h>

// Every malloc zone of the system allocator takes an 8 MB region for "small"
// blocks per CPU and keeps it for good, however little is left in it. The GPU
// driver makes three zones of its own, IOSurface one, and CoreFoundation and
// libGFXShared use two more that Gecko's allocator (jemalloc, the default zone)
// never sees: on the iPhone 4S that was 60-80 MB of address space holding
// 1-2 MB of blocks. Here new zones become copies of the jemalloc zone, and the
// two made before main hand new blocks to jemalloc too; the 768 MB a 32-bit
// app gets on iOS 6 are what LegacyFox runs out of first.
//
// UIKit's web thread also starts JavaScriptCore, which maps a 16 MB pool for
// JIT code nobody runs here; that mapping is refused, and JavaScriptCore then
// stays with its interpreter (it is built to, for apps without dynamic code).

static malloc_zone_t *jemalloc;

// A zone made by malloc_create_zone: jemalloc's functions (they look a block's
// owner up themselves) in a page of its own, as malloc_set_zone_name
// mprotects the zone. It is never destroyed: blocks may outlive it.
static void ProxyDestroy(malloc_zone_t *zone) {}

static malloc_zone_t *ProxyZone(void) {
    vm_address_t page = 0;
    if (vm_allocate(mach_task_self(), &page, vm_page_size, VM_FLAGS_ANYWHERE) != KERN_SUCCESS)
        return NULL;
    malloc_zone_t *zone = (malloc_zone_t *)page;
    *zone = *jemalloc;
    zone->zone_name = NULL;
    zone->destroy = ProxyDestroy;
    return zone;
}

static malloc_zone_t *LFCreateZone(vm_size_t start_size, unsigned flags) {
    return ProxyZone();
}

// Zones that already have blocks: new ones come from jemalloc, the old ones
// still go back to the zone that gave them.
enum { kMaxPatched = 4 };
static struct { malloc_zone_t *zone; malloc_zone_t original; } patched[kMaxPatched];
static int npatched;

static malloc_zone_t *Original(malloc_zone_t *zone) {
    for (int i = 0; i < npatched; i++)
        if (patched[i].zone == zone)
            return &patched[i].original;
    return NULL;
}

static size_t PatchedSize(malloc_zone_t *zone, const void *ptr) {
    size_t size = jemalloc->size(jemalloc, ptr);
    return size ? size : Original(zone)->size(zone, ptr);
}

static void *PatchedMalloc(malloc_zone_t *zone, size_t size) {
    return jemalloc->malloc(jemalloc, size);
}

static void *PatchedCalloc(malloc_zone_t *zone, size_t count, size_t size) {
    return jemalloc->calloc(jemalloc, count, size);
}

static void *PatchedValloc(malloc_zone_t *zone, size_t size) {
    return jemalloc->valloc(jemalloc, size);
}

static void *PatchedMemalign(malloc_zone_t *zone, size_t alignment, size_t size) {
    return jemalloc->memalign(jemalloc, alignment, size);
}

static void PatchedFree(malloc_zone_t *zone, void *ptr) {
    if (!ptr)
        return;
    if (jemalloc->size(jemalloc, ptr))
        jemalloc->free(jemalloc, ptr);
    else
        Original(zone)->free(zone, ptr);
}

static void PatchedFreeDefiniteSize(malloc_zone_t *zone, void *ptr, size_t size) {
    PatchedFree(zone, ptr);
}

static void *PatchedRealloc(malloc_zone_t *zone, void *ptr, size_t size) {
    // (jemalloc's zone takes no null pointer.)
    if (!ptr)
        return jemalloc->malloc(jemalloc, size);
    if (jemalloc->size(jemalloc, ptr))
        return jemalloc->realloc(jemalloc, ptr, size);
    malloc_zone_t *original = Original(zone);
    size_t old = original->size(zone, ptr);
    void *moved = jemalloc->malloc(jemalloc, size);
    if (!moved)
        return NULL;
    memcpy(moved, ptr, old < size ? old : size);
    original->free(zone, ptr);
    return moved;
}

static unsigned PatchedBatchMalloc(malloc_zone_t *zone, size_t size, void **results, unsigned count) {
    unsigned i = 0;
    for (; i < count && (results[i] = jemalloc->malloc(jemalloc, size)); i++)
        ;
    return i;
}

static void PatchedBatchFree(malloc_zone_t *zone, void **ptrs, unsigned count) {
    for (unsigned i = 0; i < count; i++)
        PatchedFree(zone, ptrs[i]);
}

static void Patch(malloc_zone_t *zone) {
    if (npatched == kMaxPatched || zone->version < 6)
        return;
    patched[npatched].zone = zone;
    patched[npatched].original = *zone;
    // The table sits in a read-only page of its own (malloc mprotects it).
    vm_address_t page = (vm_address_t)zone & ~(vm_page_size - 1);
    if (mprotect((void *)page, vm_page_size, PROT_READ | PROT_WRITE) != 0)
        return;
    npatched++;
    zone->size = PatchedSize;
    zone->malloc = PatchedMalloc;
    zone->calloc = PatchedCalloc;
    zone->valloc = PatchedValloc;
    zone->free = PatchedFree;
    zone->realloc = PatchedRealloc;
    zone->batch_malloc = PatchedBatchMalloc;
    zone->batch_free = PatchedBatchFree;
    zone->memalign = PatchedMemalign;
    zone->free_definite_size = PatchedFreeDefiniteSize;
}

static void *(*systemMmap)(void *, size_t, int, int, int, off_t);
static void *JSCMmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset) {
    if ((prot & PROT_EXEC) && fd == VM_MAKE_TAG(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR)) {
        errno = ENOMEM;
        return MAP_FAILED;
    }
    return systemMmap(addr, len, prot, flags, fd, offset);
}

// malloc_create_zone (and JavaScriptCore's mmap) are rebound in every image's
// symbol pointers, as fishhook does: the GPU driver is loaded later, so images
// are handled as they come.
static void Rebind(const struct mach_header *header, intptr_t slide) {
    const struct segment_command *linkedit = NULL;
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysymtab = NULL;
    uintptr_t cur = (uintptr_t)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++, cur += ((const struct load_command *)cur)->cmdsize) {
        const struct load_command *command = (const struct load_command *)cur;
        if (command->cmd == LC_SEGMENT && !strcmp(((const struct segment_command *)command)->segname, SEG_LINKEDIT))
            linkedit = (const struct segment_command *)command;
        else if (command->cmd == LC_SYMTAB)
            symtab = (const struct symtab_command *)command;
        else if (command->cmd == LC_DYSYMTAB)
            dysymtab = (const struct dysymtab_command *)command;
    }
    if (!linkedit || !symtab || !dysymtab || !dysymtab->nindirectsyms)
        return;
    Dl_info info;
    bool jsc = dladdr(header, &info) && info.dli_fname && strstr(info.dli_fname, "/JavaScriptCore.framework/");
    uintptr_t base = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    const struct nlist *symbols = (const struct nlist *)(base + symtab->symoff);
    const char *strings = (const char *)(base + symtab->stroff);
    const uint32_t *indirect = (const uint32_t *)(base + dysymtab->indirectsymoff);
    cur = (uintptr_t)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++, cur += ((const struct load_command *)cur)->cmdsize) {
        const struct segment_command *segment = (const struct segment_command *)cur;
        if (segment->cmd != LC_SEGMENT || strcmp(segment->segname, SEG_DATA))
            continue;
        const struct section *section = (const struct section *)(segment + 1);
        for (uint32_t j = 0; j < segment->nsects; j++, section++) {
            uint32_t type = section->flags & SECTION_TYPE;
            if (type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS)
                continue;
            void **pointers = (void **)((uintptr_t)slide + section->addr);
            for (uint32_t k = 0; k < section->size / sizeof(void *); k++) {
                uint32_t symbol = indirect[section->reserved1 + k];
                if (symbol & (INDIRECT_SYMBOL_ABS | INDIRECT_SYMBOL_LOCAL))
                    continue;
                const char *name = strings + symbols[symbol].n_un.n_strx;
                if (!strcmp(name, "_malloc_create_zone"))
                    pointers[k] = (void *)LFCreateZone;
                else if (jsc && !strcmp(name, "_mmap"))
                    pointers[k] = (void *)JSCMmap;
            }
        }
    }
}

void LFAddressSpaceInstall(void) {
    malloc_zone_t *zone = malloc_default_zone();
    // Only over Gecko's allocator.
    if (!zone || !zone->zone_name || strcmp(zone->zone_name, "jemalloc_zone") || zone->version < 6)
        return;
    jemalloc = zone;
    systemMmap = dlsym(RTLD_DEFAULT, "mmap");
    vm_address_t *zones = NULL;
    unsigned count = 0;
    if (malloc_get_all_zones(mach_task_self(), NULL, &zones, &count) == KERN_SUCCESS)
        for (unsigned i = 0; i < count; i++) {
            malloc_zone_t *z = (malloc_zone_t *)zones[i];
            const char *name = malloc_get_zone_name(z);
            if (name && (!strcmp(name, "DefaultMallocZone") || !strcmp(name, "GFXMallocZone")))
                Patch(z);
        }
    _dyld_register_func_for_add_image(Rebind);
}
