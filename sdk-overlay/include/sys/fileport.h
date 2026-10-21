/* LegacyFox SDK overlay: fileport syscalls exist in the iOS kernel (4.3+);
 * the header is macOS-only. Weak, as nothing calls them in one process. */
#ifndef LEGACYFOX_SYS_FILEPORT_H
#define LEGACYFOX_SYS_FILEPORT_H
#include <sys/cdefs.h>
#include <mach/port.h>
__BEGIN_DECLS
typedef mach_port_t fileport_t;
#define FILEPORT_NULL ((fileport_t)0)
int fileport_makeport(int fd, fileport_t *port) __attribute__((weak_import));
int fileport_makefd(fileport_t port) __attribute__((weak_import));
__END_DECLS
#endif
