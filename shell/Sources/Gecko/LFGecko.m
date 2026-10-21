#import "LFGecko.h"
#include <stdio.h>

extern int MainProcessInit(int argc, char** argv, id<SwiftGeckoViewRuntime> runtime);

// ---- LFEventDispatcher -------------------------------------------------------

// An EventCallback that hands Gecko's answer to a block, once, on the main
// thread: (result, nil) or (nil, error).
@interface LFBlockCallback : NSObject <EventCallback> {
    LFReply _reply;
}
- (id)initWithReply:(LFReply)reply;
@end

@implementation LFBlockCallback

- (id)initWithReply:(LFReply)reply {
    if ((self = [super init]))
        _reply = [reply copy];
    return self;
}

- (void)deliver:(id)result error:(id)error {
    LFReply reply = _reply;
    _reply = nil;
    if (!reply)
        return;
    void (^call)(void) = ^{
        reply(result == [NSNull null] ? nil : result, error);
        [reply release];
    };
    if ([NSThread isMainThread])
        call();
    else
        dispatch_async(dispatch_get_main_queue(), call);
}

- (void)sendSuccess:(id)response { [self deliver:response error:nil]; }
- (void)sendError:(id)response { [self deliver:nil error:response ? response : @"error"]; }

- (void)dealloc {
    [_reply release];
    [super dealloc];
}

@end

@implementation LFEventDispatcher

- (id)init {
    if ((self = [super init])) {
        _queue = [[NSMutableArray alloc] init];
        _handlers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addHandler:(LFEventHandler)handler forType:(NSString*)type {
    NSMutableArray* list = [_handlers objectForKey:type];
    if (!list) {
        list = [NSMutableArray array];
        [_handlers setObject:list forKey:type];
    }
    LFEventHandler copy = [handler copy];
    [list addObject:copy];
    [copy release];
}

- (void)dispatch:(NSString*)type message:(NSDictionary*)message {
    [self dispatch:type message:message reply:nil];
}

- (void)dispatch:(NSString*)type message:(NSDictionary*)message reply:(LFReply)reply {
    NSDictionary* msg = message ? message : [NSDictionary dictionary];
    // Always a callback: Gecko's request handlers expect one to answer.
    id cb = [[[LFBlockCallback alloc] initWithReply:reply] autorelease];
    if (_queue) {
        [_queue addObject:[NSArray arrayWithObjects:type, msg, cb, nil]];
    } else {
        [_gecko dispatchToGecko:type message:msg callback:cb];
    }
}

// SwiftEventDispatcher

- (void)attach:(id<GeckoEventDispatcher>)gecko {
    [_gecko release];
    _gecko = [gecko retain];
}

- (void)dispatchToSwift:(NSString*)type message:(id)message callback:(id<EventCallback>)callback {
    fprintf(stderr, "LegacyFox: <- %s\n", [type UTF8String]);
    NSArray* list = [_handlers objectForKey:type];
    if (!list) {
        [callback sendError:[NSString stringWithFormat:@"no handler for %@", type]];
        return;
    }
    // Gecko may call from any thread; the shell lives on the main one. On
    // the main thread the handlers run at once: a page waiting for a dialog
    // spins Gecko's own event loop, which does not drain the GCD main queue.
    if ([NSThread isMainThread]) {
        for (LFEventHandler handler in [[list copy] autorelease])
            handler(message, callback);
        return;
    }
    NSArray* handlers = [list copy];
    id msg = [message retain];
    id<EventCallback> cb = (id<EventCallback>)[(NSObject*)callback retain];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (LFEventHandler handler in handlers) {
            handler(msg, cb);
        }
        [handlers release];
        [msg release];
        [(NSObject*)cb release];
    });
}

- (BOOL)hasListener:(NSString*)type {
    return [_handlers objectForKey:type] != nil;
}

- (void)activate {
    fprintf(stderr, "LegacyFox: dispatcher %p active, %lu queued\n", self, (unsigned long)[_queue count]);
    NSArray* queued = _queue;
    _queue = nil;
    for (NSArray* item in queued) {
        [_gecko dispatchToGecko:[item objectAtIndex:0] message:[item objectAtIndex:1]
                       callback:[item objectAtIndex:2]];
    }
    [queued release];
}

- (void)dealloc {
    [_gecko release];
    [_queue release];
    [_handlers release];
    [super dealloc];
}

@end

// ---- LFGeckoRuntime ----------------------------------------------------------

@implementation LFGeckoRuntime

+ (LFGeckoRuntime*)shared {
    static LFGeckoRuntime* runtime;
    if (!runtime) {
        runtime = [[LFGeckoRuntime alloc] init];
    }
    return runtime;
}

- (id)init {
    if ((self = [super init])) {
        _runtimeDispatcher = [[LFEventDispatcher alloc] init];
        _dispatchers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (int)runWithArgc:(int)argc argv:(char**)argv {
    return MainProcessInit(argc, argv, self);
}

- (id<SwiftEventDispatcher>)runtimeDispatcher {
    return _runtimeDispatcher;
}

- (void)addHandler:(LFEventHandler)handler forType:(NSString*)type {
    [_runtimeDispatcher addHandler:handler forType:type];
}

- (void)dispatch:(NSString*)type message:(NSDictionary*)message {
    [_runtimeDispatcher dispatch:type message:message];
}

- (void)dispatch:(NSString*)type message:(NSDictionary*)message reply:(LFReply)reply {
    [_runtimeDispatcher dispatch:type message:message reply:reply];
}

- (id<SwiftEventDispatcher>)dispatcherByName:(const char*)name {
    NSString* key = [NSString stringWithUTF8String:name];
    LFEventDispatcher* dispatcher = [_dispatchers objectForKey:key];
    if (!dispatcher) {
        dispatcher = [[[LFEventDispatcher alloc] init] autorelease];
        [_dispatchers setObject:dispatcher forKey:key];
    }
    return dispatcher;
}

@end

// ---- LFGeckoSession ----------------------------------------------------------

static NSString* LFNewWindowId(void) {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString* s = (NSString*)CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    NSString* id_ = [[s stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    [s release];
    return id_;
}

// The page shown when a page cannot be loaded (GeckoView:OnLoadError), as a
// data: address: what went wrong, in the 2012 manner, and a retry button.
static NSString* LFErrorPage(NSDictionary* m) {
    NSString* uri = [[m objectForKey:@"uri"] isKindOfClass:[NSString class]] ? [m objectForKey:@"uri"] : @"";
    unsigned long error = [[m objectForKey:@"error"] unsignedLongValue];
    int errorClass = [[m objectForKey:@"errorClass"] intValue];
    int module = [[m objectForKey:@"errorModule"] intValue];
    NSString* title = @"Не удалось открыть страницу";
    NSString* text = @"Что-то помешало загрузить эту страницу.";
    switch (error) {
    case 0x804B001E: title = @"Сайт не найден";
        text = @"Не удаётся найти сервер. Проверьте адрес и подключение к интернету."; break;
    case 0x804B000E: title = @"Сайт не отвечает";
        text = @"Сервер слишком долго не отвечает. Возможно, он перегружен, или мешает VPN."; break;
    case 0x804B000D: title = @"Соединение отклонено";
        text = @"Сервер отказался принять соединение."; break;
    case 0x804B0010: title = @"Нет подключения";
        text = @"Похоже, iPad не подключён к интернету."; break;
    case 0x804B0014: case 0x804B0047: title = @"Соединение прервано";
        text = @"Соединение оборвалось, пока страница загружалась."; break;
    case 0x804B001F: title = @"Страница перенаправляет по кругу";
        text = @"Сайт перенаправляет запросы так, что они никогда не закончатся."; break;
    }
    if (errorClass || module == 21) {
        title = @"Небезопасное соединение";
        text = @"Не удалось проверить, что это действительно тот сайт: у него неверный или устаревший сертификат, "
               @"или проверке мешает сеть.";
    }
    NSString* safeUri = [[[uri stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
        stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    NSString* html = [NSString stringWithFormat:
        @"<!DOCTYPE html><html><head><meta charset=utf-8><meta name=viewport content='width=device-width'>"
        @"<title>%@</title><style>"
        @"body{margin:0;font:16px Helvetica,sans-serif;color:#333;background:#e6e6e6;"
        @"background:linear-gradient(#f2f2f2,#d9d9d9);min-height:100vh}"
        @".box{max-width:520px;margin:12vh auto 0;padding:28px 30px;background:#fff;border-radius:10px;"
        @"border:1px solid #bbb;box-shadow:0 2px 8px rgba(0,0,0,.25)}"
        @"h1{font-size:22px;margin:0 0 12px;color:#222;text-shadow:0 1px #fff}"
        @"p{line-height:1.45;margin:0 0 10px}.u{color:#888;font-size:13px;word-break:break-all}"
        @"button{margin-top:14px;font:bold 16px Helvetica;color:#fff;padding:10px 26px;border-radius:6px;"
        @"border:1px solid #8a3d07;background:linear-gradient(#f39a3d,#d9620b);text-shadow:0 -1px #8a3d07;"
        @"box-shadow:inset 0 1px rgba(255,255,255,.4)}</style></head><body><div class=box>"
        @"<h1>%@</h1><p>%@</p><p class=u>%@</p>"
        @"<button onclick=\"location.replace('%@')\">Попробовать снова</button></div></body></html>",
        title, title, text, safeUri, [safeUri stringByReplacingOccurrencesOfString:@"'" withString:@"%27"]];
    NSString* encoded = (NSString*)CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)html, NULL, CFSTR("#%?&=+;:/'\"<> "), kCFStringEncodingUTF8);
    NSString* result = [@"data:text/html;charset=utf-8," stringByAppendingString:encoded];
    [encoded release];
    return result;
}

@implementation LFGeckoSession

@synthesize delegate = _delegate;
@synthesize privateMode = _privateMode;

- (id)init {
    if ((self = [super init])) {
        _dispatcher = [[LFEventDispatcher alloc] init];
        _state = [[NSMutableDictionary alloc] init];
        LFGeckoSession* session = self;  // not retained: the session owns the dispatcher

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([[m objectForKey:@"isTopLevel"] boolValue] &&
                [session.delegate respondsToSelector:@selector(session:locationChanged:canGoBack:canGoForward:)]) {
                id uri = [m objectForKey:@"uri"];
                [session.delegate session:session
                          locationChanged:[uri isKindOfClass:[NSString class]] ? uri : nil
                                canGoBack:[[m objectForKey:@"canGoBack"] boolValue]
                             canGoForward:[[m objectForKey:@"canGoForward"] boolValue]];
            }
            [cb sendSuccess:nil];
        } forType:@"GeckoView:LocationChange"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([session.delegate respondsToSelector:@selector(session:titleChanged:)])
                [session.delegate session:session titleChanged:[m objectForKey:@"title"]];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:PageTitleChanged"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([session.delegate respondsToSelector:@selector(session:progressChanged:)])
                [session.delegate session:session
                          progressChanged:[[m objectForKey:@"progress"] intValue] / 100.0f];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:ProgressChanged"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([session.delegate respondsToSelector:@selector(sessionPageStarted:)])
                [session.delegate sessionPageStarted:session];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:PageStart"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([session.delegate respondsToSelector:@selector(session:pageStopped:)])
                [session.delegate session:session pageStopped:[[m objectForKey:@"success"] boolValue]];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:PageStop"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            [session updateState:[m objectForKey:@"data"]];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:StateUpdated"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if (![session.delegate respondsToSelector:@selector(session:prompt:reply:)]) {
                [cb sendSuccess:nil];
                return;
            }
            id<EventCallback> callback = [cb retain];
            __block BOOL replied = NO;
            // GeckoView wraps the prompt: { prompt: { id, type, ... } }.
            NSDictionary* prompt = [m objectForKey:@"prompt"];
            if (![prompt isKindOfClass:[NSDictionary class]])
                prompt = m;
            [session.delegate session:session prompt:prompt reply:^(NSDictionary* result) {
                if (replied)
                    return;
                replied = YES;
                [callback sendSuccess:result];
                [callback release];
            }];
        } forType:@"GeckoView:Prompt"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([session.delegate respondsToSelector:@selector(session:dismissPrompt:)])
                [session.delegate session:session dismissPrompt:[m objectForKey:@"id"]];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:Prompt:Dismiss"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            [cb sendSuccess:LFErrorPage(m)];
        } forType:@"GeckoView:OnLoadError"];

        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            if ([session.delegate respondsToSelector:@selector(session:contextMenu:)])
                [session.delegate session:session contextMenu:m];
            [cb sendSuccess:nil];
        } forType:@"GeckoView:ContextMenu"];

        // Every navigation is allowed; new windows open in this tab for now.
        // The answer is "handled by the app": NO lets Gecko load the page.
        // Addresses Gecko cannot show (mailto:, tel:, App Store links) go to
        // iOS instead.
        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            NSString* uri = [m objectForKey:@"uri"];
            NSString* scheme = [uri isKindOfClass:[NSString class]] ? [[[NSURL URLWithString:uri] scheme] lowercaseString] : nil;
            static NSSet* web;
            if (!web)
                web = [[NSSet alloc] initWithObjects:@"http", @"https", @"about", @"data", @"blob", @"javascript",
                                                      @"file", @"resource", @"chrome", @"view-source", @"moz-extension", nil];
            BOOL external = scheme && ![web containsObject:scheme];
            if (external)
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:uri]];
            [cb sendSuccess:[NSNumber numberWithBool:external]];
        } forType:@"GeckoView:OnLoadRequest"];
        [_dispatcher addHandler:^(NSDictionary* m, id<EventCallback> cb) {
            LFGeckoSession* opened = nil;
            NSString* newId = [m objectForKey:@"newSessionId"];
            if ([newId isKindOfClass:[NSString class]] &&
                [session.delegate respondsToSelector:@selector(session:newSessionWithId:uri:)])
                opened = [session.delegate session:session newSessionWithId:newId uri:[m objectForKey:@"uri"]];
            [cb sendSuccess:[NSNumber numberWithBool:opened != nil]];
        } forType:@"GeckoView:OnNewSession"];
    }
    return self;
}

- (void)open {
    [self openWithWindowId:LFNewWindowId()];
}

- (void)openWithWindowId:(NSString*)windowId {
    if (_window)
        return;
    NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:0], @"screenId",
        [NSNumber numberWithBool:NO], @"useTrackingProtection",
        [NSNumber numberWithInt:0], @"userAgentMode",    // mobile
        [NSNumber numberWithInt:0], @"viewportMode",     // mobile
        [NSNumber numberWithInt:0], @"displayMode",      // browser
        [NSNumber numberWithBool:YES], @"suspendMediaWhenInactive",
        [NSNumber numberWithBool:YES], @"allowJavascript",
        [NSNumber numberWithBool:NO], @"fullAccessibilityTree",
        [NSNumber numberWithBool:NO], @"isPopup",
        // GeckoView's modules compare these with null, not undefined.
        [NSNull null], @"chromeUri",
        [NSNull null], @"userAgentOverride",
        [NSNull null], @"sessionContextId",
        [NSNull null], @"unsafeSessionContextId",
        nil];
    NSDictionary* modules = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:YES], @"GeckoViewNavigation",
        [NSNumber numberWithBool:YES], @"GeckoViewProgress",
        [NSNumber numberWithBool:YES], @"GeckoViewContent",
        nil];
    NSDictionary* init = [NSDictionary dictionaryWithObjectsAndKeys:
        settings, @"settings", modules, @"modules", nil];
    [_settings release];
    _settings = [settings retain];
    _window = [GeckoViewOpenWindow(windowId, _dispatcher, init, _privateMode) retain];
}

- (void)close {
    [_window close];
    [_window release];
    _window = nil;
}

- (UIView*)view {
    return [_window view];
}

- (void)loadURL:(NSString*)url {
    [_dispatcher dispatch:@"GeckoView:LoadUri"
                  message:[NSDictionary dictionaryWithObjectsAndKeys:
                               url, @"uri",
                               [NSNumber numberWithInt:0], @"flags",
                               [NSNumber numberWithInt:1], @"headerFilter",  // CORS safelisted
                               nil]];
}

- (void)goBack {
    [_dispatcher dispatch:@"GeckoView:GoBack"
                  message:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                      forKey:@"userInteraction"]];
}

- (void)goForward {
    [_dispatcher dispatch:@"GeckoView:GoForward"
                  message:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                      forKey:@"userInteraction"]];
}

- (void)reload {
    [_dispatcher dispatch:@"GeckoView:Reload"
                  message:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0] forKey:@"flags"]];
}

- (BOOL)desktopMode {
    return [[_settings objectForKey:@"userAgentMode"] intValue] == 1;
}

- (void)setDesktopMode:(BOOL)desktop {
    // GeckoView's USER_AGENT_MODE_DESKTOP and VIEWPORT_MODE_DESKTOP are 1.
    [_settings setObject:[NSNumber numberWithInt:desktop ? 1 : 0] forKey:@"userAgentMode"];
    [_settings setObject:[NSNumber numberWithInt:desktop ? 1 : 0] forKey:@"viewportMode"];
    [_dispatcher dispatch:@"GeckoView:UpdateSettings" message:_settings];
    [self reload];
}

- (void)find:(NSString*)text backwards:(BOOL)backwards reply:(LFReply)reply {
    NSMutableDictionary* msg = [NSMutableDictionary dictionary];
    if (text)
        [msg setObject:text forKey:@"searchString"];
    [msg setObject:[NSNumber numberWithBool:backwards] forKey:@"backwards"];
    [_dispatcher dispatch:@"GeckoView:DisplayMatches"
                  message:[NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithBool:YES], @"highlightAll",
                               [NSNumber numberWithBool:YES], @"dimPage",
                               [NSNumber numberWithBool:YES], @"drawOutline", nil]];
    [_dispatcher dispatch:@"GeckoView:FindInPage" message:msg reply:reply];
}

- (void)clearMatches {
    [_dispatcher dispatch:@"GeckoView:ClearMatches" message:nil];
}

- (void)stop {
    [_dispatcher dispatch:@"GeckoView:Stop" message:nil];
}

- (void)setActive:(BOOL)active {
    [_dispatcher dispatch:@"GeckoView:SetActive"
                  message:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:active]
                                                      forKey:@"active"]];
}

// GeckoView:StateUpdated carries either the whole history (fromIdx -1) or
// the entries from fromIdx + 1 on, which replace the tail of what we have.
- (void)updateState:(NSDictionary*)update {
    if (![update isKindOfClass:[NSDictionary class]])
        return;
    NSDictionary* history = [update objectForKey:@"historychange"];
    if ([history isKindOfClass:[NSDictionary class]]) {
        int from = [[history objectForKey:@"fromIdx"] intValue];
        NSMutableDictionary* merged = [[history mutableCopy] autorelease];
        [merged removeObjectForKey:@"fromIdx"];
        if (from != -1) {
            NSArray* old = [[_state objectForKey:@"history"] objectForKey:@"entries"];
            NSArray* tail = [history objectForKey:@"entries"];
            NSMutableArray* entries = [NSMutableArray array];
            if (from != INT32_MAX - 1) {
                NSUInteger keep = MIN((NSUInteger)(from + 1), [old count]);
                [entries addObjectsFromArray:[old subarrayWithRange:NSMakeRange(0, keep)]];
                if ([tail isKindOfClass:[NSArray class]])
                    [entries addObjectsFromArray:tail];
            } else if ([old isKindOfClass:[NSArray class]]) {
                [entries addObjectsFromArray:old];
            }
            [merged setObject:entries forKey:@"entries"];
        }
        [_state setObject:merged forKey:@"history"];
    }
    id scroll = [update objectForKey:@"scroll"];
    if ([scroll isKindOfClass:[NSDictionary class]])
        [_state setObject:scroll forKey:@"scrolldata"];
    id form = [update objectForKey:@"formdata"];
    if ([form isKindOfClass:[NSDictionary class]])
        [_state setObject:form forKey:@"formdata"];
}

- (NSDictionary*)sessionState {
    return [_state objectForKey:@"history"] ? [[_state copy] autorelease] : nil;
}

- (void)restoreState:(NSDictionary*)state {
    [_state setDictionary:state];
    [_dispatcher dispatch:@"GeckoView:RestoreState" message:state];
}

- (void)dealloc {
    [self close];
    [_settings release];
    [_state release];
    [_dispatcher release];
    [super dealloc];
}

@end
