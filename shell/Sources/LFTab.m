#import "LFTab.h"

@implementation LFTab

@synthesize session = _session;
@synthesize url = _url;
@synthesize title = _title;
@synthesize canGoBack = _canGoBack;
@synthesize canGoForward = _canGoForward;
@synthesize loading = _loading;
@synthesize progress = _progress;
@synthesize privateTab = _privateTab;
@synthesize thumbnail = _thumbnail;

- (NSDictionary *)archive {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (_url)
        [d setObject:_url forKey:@"url"];
    if (_title)
        [d setObject:_title forKey:@"title"];
    NSDictionary *state = _session ? [_session sessionState] : _savedState;
    if (state)
        [d setObject:state forKey:@"state"];
    return d;
}

- (id)initWithArchive:(NSDictionary *)archive {
    if ((self = [super init])) {
        _url = [[archive objectForKey:@"url"] copy];
        _title = [[archive objectForKey:@"title"] copy];
        _savedState = [[archive objectForKey:@"state"] retain];
    }
    return self;
}

- (id)initWithOpenedSessionId:(NSString *)windowId delegate:(id<LFGeckoSessionDelegate>)delegate {
    if ((self = [super init])) {
        _session = [[LFGeckoSession alloc] init];
        [_session setDelegate:delegate];
        [_session openWithWindowId:windowId];
    }
    return self;
}

- (BOOL)isLoaded {
    return _session != nil;
}

- (void)unload {
    if (!_session)
        return;
    [[_session view] removeFromSuperview];
    // Back/forward history and scroll positions come back with the page.
    [_savedState release];
    _savedState = [[_session sessionState] retain];
    [_session setDelegate:nil];
    [_session close];
    [_session release];
    _session = nil;
    _loading = NO;
    _progress = 0;
}

- (void)loadWithDelegate:(id<LFGeckoSessionDelegate>)delegate {
    // A tab without an address shows the home page and needs no Gecko page.
    if (_session || (![_url length] && !_savedState))
        return;
    _session = [[LFGeckoSession alloc] init];
    [_session setDelegate:delegate];
    [_session setPrivateMode:_privateTab];
    [_session open];
    if (![_session view])
        return;
    if (_savedState)
        [_session restoreState:_savedState];
    else if ([_url length])
        [_session loadURL:_url];
    [_savedState release];
    _savedState = nil;
}

- (NSString *)displayTitle {
    NSString *title = [_title length] ? _title : [_url length] ? _url : @"Новая вкладка";
    return _privateTab ? [@"Приватная: " stringByAppendingString:title] : title;
}

- (void)dealloc {
    [_session setDelegate:nil];
    [_session close];
    [_session release];
    [_url release];
    [_title release];
    [_savedState release];
    [_thumbnail release];
    [super dealloc];
}

@end
