// Without the engine (make GECKO=0): just enough of Gecko's entry points to
// run the shell's UI on its own. MainProcessInit starts UIKit and announces
// the launch the way Gecko's app shell does; there are no windows to open.

#import "LFGecko.h"

@interface LFStubAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation LFStubAppDelegate
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GeckoAppShellDidFinishLaunching"
                                                        object:application
                                                      userInfo:options];
    return YES;
}
@end

int MainProcessInit(int argc, char** argv, id<SwiftGeckoViewRuntime> runtime) {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([LFStubAppDelegate class]));
}

id<GeckoViewWindow> GeckoViewOpenWindow(NSString* aId, id<SwiftEventDispatcher> aDispatcher,
                                        NSDictionary* aInitData, bool aPrivateMode) {
    return nil;
}
