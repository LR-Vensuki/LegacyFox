// spawnprobe: can a process on iOS 6 start a child with posix_spawn and get
// its task port over a bootstrap name it checked in itself, the way Gecko's
// macOS launcher does (bootstrap_check_in + MachChildProcessCheckIn)?
#include <mach/mach.h>
#include <mach/bootstrap.h>
kern_return_t bootstrap_check_in(mach_port_t, const char *, mach_port_t *);
kern_return_t bootstrap_look_up(mach_port_t, const char *, mach_port_t *);
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t task;
} CheckIn;

int main(int argc, char **argv) {
    if (argc == 3 && !strcmp(argv[1], "child")) {
        mach_port_t parent;
        kern_return_t kr = bootstrap_look_up(bootstrap_port, argv[2], &parent);
        if (kr) { printf("child: bootstrap_look_up %s: %d\n", argv[2], kr); return 1; }
        CheckIn m = { 0 };
        m.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) | MACH_MSGH_BITS_COMPLEX;
        m.header.msgh_size = sizeof(m);
        m.header.msgh_remote_port = parent;
        m.body.msgh_descriptor_count = 1;
        m.task.name = mach_task_self();
        m.task.disposition = MACH_MSG_TYPE_COPY_SEND;
        m.task.type = MACH_MSG_PORT_DESCRIPTOR;
        kr = mach_msg(&m.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(m), 0, 0, 5000, 0);
        printf("child %d: sent task port: %d\n", getpid(), kr);
        return kr != 0;
    }
    char name[128];
    snprintf(name, sizeof name, "org.legacyfox.probe.%d", getpid());
    mach_port_t recv;
    kern_return_t kr = bootstrap_check_in(bootstrap_port, name, &recv);
    printf("parent %d uid %d: bootstrap_check_in %s: %d\n", getpid(), getuid(), name, kr);
    if (kr) return 1;
    char *args[] = { argv[0], "child", name, NULL };
    pid_t pid;
    int err = posix_spawn(&pid, argv[0], NULL, NULL, args, environ);
    printf("parent: posix_spawn: %d, pid %d\n", err, pid);
    if (err) return 1;
    struct { CheckIn m; mach_msg_trailer_t t; } in = { { { 0 } } };
    kr = mach_msg(&in.m.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof(in), recv, 5000, 0);
    int pidof = -1;
    if (!kr) pid_for_task(in.m.task.name, &pidof);
    printf("parent: check-in %d, task port %u is pid %d\n", kr, in.m.task.name, pidof);
    waitpid(pid, NULL, 0);
    return 0;
}
