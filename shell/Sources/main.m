#import "LFAppDelegate.h"
#import "Gecko/LFGecko.h"
#include <dlfcn.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

// Developer switch: with /var/mobile/Library/LegacyFox/debug present, output
// goes to lf.log next to it and tools/crashlog's dylib (if installed) reports
// crashes there too -- the app is started by SpringBoard, not from a shell.
static void LFDebugSetup(void) {
    struct stat st;
    if (stat("/var/mobile/Library/LegacyFox/debug", &st) != 0)
        return;
    freopen("/var/mobile/Library/LegacyFox/lf.log", "w", stderr);
    dup2(fileno(stderr), fileno(stdout));
    setvbuf(stderr, NULL, _IONBF, 0);
    // NAME=value lines in debug set Gecko's environment (MOZ_LOG and so on).
    FILE *env = fopen("/var/mobile/Library/LegacyFox/debug", "r");
    char line[8192];
    while (env && fgets(line, sizeof(line), env)) {
        line[strcspn(line, "\r\n")] = 0;
        char *eq = strchr(line, '=');
        if (eq && eq != line) {
            *eq = 0;
            setenv(line, eq + 1, 1);
        }
    }
    if (env)
        fclose(env);
    // After the environment: crashlog reads its switches (LF_TRACE_MMAP) too.
    dlopen("/var/mobile/legacyfox-test/crashlog.dylib", RTLD_NOW);
}

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    LFDebugSetup();
    // Gecko owns the application: it calls UIApplicationMain and tells the
    // shell when to build its window (GeckoAppShellDidFinishLaunching).
    [LFAppDelegate prepare];
    int ret = [[LFGeckoRuntime shared] runWithArgc:argc argv:argv];
    [pool release];
    return ret;
}
