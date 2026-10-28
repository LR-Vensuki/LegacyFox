// lfvm PID [MIN_KB]: a task's address space by VM tag, its regions of at least
// MIN_KB (4096) with their files, and the free holes below the shared region.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mach/mach.h>

int proc_regionfilename(int pid, uint64_t address, void *buffer, uint32_t buffersize);
int main(int argc, char **argv) {
    task_t t;
    if (argc < 2 || task_for_pid(mach_task_self(), atoi(argv[1]), &t) != KERN_SUCCESS) { fprintf(stderr, "task_for_pid failed\n"); return 1; }
    unsigned long minsz = (argc > 2 ? strtoul(argv[2], NULL, 0) : 4096) << 10;
    unsigned long long bytag[256] = {0}, restag[256] = {0}, total = 0, freesum = 0, hole = 0;
    vm_address_t a = 0, end = 0x1000; vm_size_t sz; natural_t depth = 0;
    printf("regions (>=%lu KB): start size_KB resident_KB tag prot file\n", minsz >> 10);
    for (;;) {
        vm_region_submap_info_data_64_t info; mach_msg_type_number_t cnt = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (vm_region_recurse_64(t, &a, &sz, &depth, (vm_region_recurse_info_t)&info, &cnt) != KERN_SUCCESS) break;
        if (info.is_submap) { depth++; continue; }
        if (a < 0x30000000 && a > end) {
            freesum += a - end;
            if (a - end > hole) hole = a - end;
            if (a - end >= minsz) printf("0x%08lx %7lu       - free\n", end, (a - end) >> 10);
        }
        unsigned tag = info.user_tag & 255;
        bytag[tag] += sz; restag[tag] += (unsigned long long)info.pages_resident * 4096; total += sz;
        if (sz >= minsz) {
            char path[1024] = "";
            proc_regionfilename(atoi(argv[1]), a, path, sizeof path);
            printf("0x%08lx %7lu %7u %3u %d %s\n", a, sz >> 10, info.pages_resident * 4, tag, info.protection, path);
        }
        a += sz;
        if (a <= 0x30000000) end = a;
    }
    if (end < 0x30000000) { freesum += 0x30000000 - end; if (0x30000000 - end > hole) hole = 0x30000000 - end; }
    printf("total %llu MB, free below 0x30000000 %llu MB, biggest hole %llu MB, by tag (MB mapped/resident):", total >> 20, freesum >> 20, hole >> 20);
    for (int i = 0; i < 256; i++) if (bytag[i] >> 20) printf(" %d:%llu/%llu", i, bytag[i] >> 20, restag[i] >> 20);
    printf("\n");
    return 0;
}
