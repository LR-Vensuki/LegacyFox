// The shell's side of Gecko's embedding protocols (widget/uikit/
// GeckoViewSwiftSupport.h), in Objective-C for iOS 4-7: Mozilla's own
// wrapper is Swift and needs iOS 13.

#import "GeckoViewSwiftSupport.h"

typedef void (^LFEventHandler)(NSDictionary* message, id<EventCallback> callback);
// Gecko's answer to a request: result, or nil and an error.
typedef void (^LFReply)(id result, id error);

// One message bus between the shell and Gecko, per window and one for the
// runtime. Messages sent before Gecko attaches are queued.
@interface LFEventDispatcher : NSObject <SwiftEventDispatcher> {
    id<GeckoEventDispatcher> _gecko;
    NSMutableArray* _queue;
    NSMutableDictionary* _handlers;
}
- (void)addHandler:(LFEventHandler)handler forType:(NSString*)type;
- (void)dispatch:(NSString*)type message:(NSDictionary*)message;
- (void)dispatch:(NSString*)type message:(NSDictionary*)message reply:(LFReply)reply;
@end

@interface LFGeckoRuntime : NSObject <SwiftGeckoViewRuntime> {
    LFEventDispatcher* _runtimeDispatcher;
    NSMutableDictionary* _dispatchers;
}
+ (LFGeckoRuntime*)shared;
// Runs Gecko; never returns. Gecko calls UIApplicationMain itself and posts
// GeckoAppShellDidFinishLaunching when the shell may build its window.
- (int)runWithArgc:(int)argc argv:(char**)argv;
// Messages from Gecko as a whole (LegacyFox:Downloads:Started and so on).
- (void)addHandler:(LFEventHandler)handler forType:(NSString*)type;
// Messages to Gecko as a whole (GeckoView's runtime: storage, settings).
- (void)dispatch:(NSString*)type message:(NSDictionary*)message;
- (void)dispatch:(NSString*)type message:(NSDictionary*)message reply:(LFReply)reply;
@end

// GeckoView StorageController flags for GeckoView:ClearData.
enum {
    LFClearCookies = 1 << 0,
    LFClearNetworkCache = 1 << 1,
    LFClearImageCache = 1 << 2,
    LFClearDOMStorages = 1 << 4,
    LFClearAuthSessions = 1 << 5,
    LFClearPermissions = 1 << 6,
    LFClearSiteSettings = 1 << 7,
    LFClearSiteData = (1 << 8) | 1 | (1 << 1) | (1 << 2) | (1 << 4) | (1 << 6) | (1 << 7),
    LFClearAll = 1 << 9,
};

@class LFGeckoSession;

@protocol LFGeckoSessionDelegate <NSObject>
@optional
- (void)session:(LFGeckoSession*)session locationChanged:(NSString*)url
      canGoBack:(BOOL)back canGoForward:(BOOL)forward;
- (void)session:(LFGeckoSession*)session titleChanged:(NSString*)title;
- (void)session:(LFGeckoSession*)session progressChanged:(float)progress;
- (void)sessionPageStarted:(LFGeckoSession*)session;
- (void)session:(LFGeckoSession*)session pageStopped:(BOOL)success;
// A long press on a link or an image: { uri, elementSrc, elementType, title,
// linkText, screenX, screenY }.
- (void)session:(LFGeckoSession*)session contextMenu:(NSDictionary*)info;
// GeckoView:Prompt (alert, confirm, <select>, logins...): reply exactly once,
// with the result dictionary, or nil for "dismissed".
- (void)session:(LFGeckoSession*)session prompt:(NSDictionary*)prompt
          reply:(void (^)(NSDictionary* result))reply;
// GeckoView:Prompt:Dismiss: the page no longer needs the prompt with this id.
- (void)session:(LFGeckoSession*)session dismissPrompt:(NSString*)promptId;
// A link with target=_blank or window.open(): return a session opened with
// openWithWindowId:newSessionId (Gecko loads uri into it), or nil to refuse.
- (LFGeckoSession*)session:(LFGeckoSession*)session newSessionWithId:(NSString*)newSessionId
                       uri:(NSString*)uri;
@end

// A browser tab: one Gecko window and its view.
@interface LFGeckoSession : NSObject {
    LFEventDispatcher* _dispatcher;
    NSMutableDictionary* _state;
    NSMutableDictionary* _settings;
    BOOL _privateMode;
    id<GeckoViewWindow> _window;
    id<LFGeckoSessionDelegate> _delegate;
}
@property(nonatomic, assign) id<LFGeckoSessionDelegate> delegate;
// Private browsing: no history, cookies and cache kept apart and forgotten.
// Set before open.
@property(nonatomic) BOOL privateMode;
@property(nonatomic, readonly) UIView* view;
- (void)open;
- (void)openWithWindowId:(NSString*)windowId;
// Find in page: text (nil: the next match of the last one); the reply gets
// GeckoView's { found, current, total }.
- (void)find:(NSString*)text backwards:(BOOL)backwards reply:(LFReply)reply;
- (void)clearMatches;
// Scrolls smoothly by screens (GeckoView:ScrollBy), negative is up.
- (void)scrollByScreens:(float)screens;
// The User-Agent pages see (nil: Gecko's own), for sessions opened from
// now on; -applyUserAgent passes it to an open one.
+ (void)setUserAgent:(NSString*)agent;
- (void)applyUserAgent;
// The desktop site: a Mac user agent and a desktop viewport; reloads.
@property(nonatomic) BOOL desktopMode;
- (void)close;
- (void)loadURL:(NSString*)url;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stop;
- (void)setActive:(BOOL)active;
// History, scroll positions and form data, kept up to date from Gecko the
// way GeckoView's SessionState does; restoreState: brings a tab back.
- (NSDictionary*)sessionState;
- (void)restoreState:(NSDictionary*)state;
@end
