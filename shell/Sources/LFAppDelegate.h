@class LFBrowserViewController;

// Not the UIApplication delegate (Gecko's app shell is): it builds the shell's
// window once Gecko has launched.
@interface LFAppDelegate : NSObject {
    UIWindow *_window;
    LFBrowserViewController *_browser;
}
+ (void)prepare;
@end
