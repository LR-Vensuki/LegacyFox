#import "LFAppDelegate.h"
#import "LFBrowserViewController.h"
#include <stdio.h>
#include <mach/mach.h>
#include <stdlib.h>

static LFAppDelegate *gShell;

@implementation LFAppDelegate

+ (void)prepare {
    gShell = [[LFAppDelegate alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:gShell
                                             selector:@selector(geckoDidLaunch:)
                                                 name:@"GeckoAppShellDidFinishLaunching"
                                               object:nil];
}

- (void)geckoDidLaunch:(NSNotification *)note {
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _browser = [[LFBrowserViewController alloc] init];
    if ([_window respondsToSelector:@selector(setRootViewController:)])
        [_window setRootViewController:_browser];
    else
        [_window addSubview:[_browser view]];
    [_window makeKeyAndVisible];
    if (getenv("LF_LOG_MEMORY"))
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(logMemory)
                                       userInfo:nil repeats:YES];
    if (getenv("LF_DUMP_VIEWS"))
        [self performSelector:@selector(dumpViews) withObject:nil afterDelay:20];
}

// Developer aid (LF_LOG_MEMORY in the debug file): resident memory every 5 s.
- (void)logMemory {
    task_basic_info_data_t info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS)
        fprintf(stderr, "LegacyFox: resident %u MB, virtual %u MB\n",
                (unsigned)(info.resident_size >> 20), (unsigned)(info.virtual_size >> 20));
}

// Developer aid (LF_DUMP_VIEWS in the debug file): every window's view tree.
- (void)dumpViews {
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        NSString *tree = [w performSelector:@selector(recursiveDescription)];
        fprintf(stderr, "LegacyFox: window %s\n%s\n", [[w description] UTF8String], [tree UTF8String]);
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_browser release];
    [_window release];
    [super dealloc];
}

@end
