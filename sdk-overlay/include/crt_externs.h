/* LegacyFox SDK overlay: libSystem has these on iOS too; the header is macOS-only. */
#ifndef LEGACYFOX_CRT_EXTERNS_H
#define LEGACYFOX_CRT_EXTERNS_H
#include <sys/cdefs.h>
__BEGIN_DECLS
extern char ***_NSGetArgv(void);
extern int *_NSGetArgc(void);
extern char ***_NSGetEnviron(void);
extern char **_NSGetProgname(void);
struct mach_header;
extern struct mach_header *_NSGetMachExecuteHeader(void);
__END_DECLS
#endif
