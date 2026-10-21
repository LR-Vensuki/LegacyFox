#import "LFBrowserViewController.h"
#include <dlfcn.h>
#import <QuartzCore/QuartzCore.h>
#import "LFTopBar.h"
#import "LFTab.h"
#import "LFStore.h"
#import "LFSettings.h"
#import "LFPasswords.h"
#import "LFAccount.h"
#import "LFDownloads.h"
#import "LFFennec.h"

@implementation LFBrowserViewController

- (void)loadView {
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    UIView *root = [[UIView alloc] initWithFrame:frame];
    [root setBackgroundColor:[UIColor blackColor]];
    [root setAutoresizesSubviews:NO];
    CGFloat w = frame.size.width, h = frame.size.height;
    CGFloat barHeight = [LFTopBar height];

    _pageView = [[UIView alloc] initWithFrame:CGRectMake(0, barHeight, w, h - barHeight - [LFTopBar bottomHeight])];
    [_pageView setBackgroundColor:[UIColor whiteColor]];
    _placeholder = [[UILabel alloc] initWithFrame:CGRectInset([_pageView bounds], 20, 20)];
    [_placeholder setNumberOfLines:0];
    [_placeholder setTextAlignment:UITextAlignmentCenter];
    [_placeholder setTextColor:[UIColor grayColor]];
    [_placeholder setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_pageView addSubview:_placeholder];
    [root addSubview:_pageView];

    _topBar = [[LFTopBar alloc] initWithFrame:CGRectMake(0, 0, w, barHeight)];
    [_topBar setDelegate:self];
    [root addSubview:_topBar];
    if ([_topBar bottomBar])
        [root addSubview:[_topBar bottomBar]];

    // Navigation bars in Firefox Home's blue, as Mozilla's iOS app had them.
    if ([UINavigationBar respondsToSelector:@selector(appearance)]) {
        UIImage *header = [[LFFennec home:@"header"] stretchableImageWithLeftCapWidth:16 topCapHeight:0];
        [[UINavigationBar appearance] setBackgroundImage:header forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:35 / 255.0 green:65 / 255.0
                                                                    blue:113 / 255.0 alpha:1]];
    }

    _tabsList = [[LFTabsList alloc] init];
    [_tabsList setDelegate:self];
    _awesome = [[LFAwesomeController alloc] init];
    [_awesome setDelegate:self];

    [self setView:root];
    [root release];
    [self layoutMain];

    _tabs = [[NSMutableArray alloc] init];
    _recent = [[NSMutableArray alloc] init];
    [[LFStore shared] start];
    // Sync and the account WebChannel start before any page loads: an
    // account page restored from the last run must find the channel open.
    [self startSync];
    const char *start = getenv("LF_START_URL");
    if (getenv("LF_DEMO")) {
        // Pictures of the interface: a few made-up tabs, not the user's.
        NSArray *demo = [NSArray arrayWithObjects:@"https://ru.wikipedia.org/", @"Википедия — свободная энциклопедия",
                                                  @"https://www.mozilla.org/ru/", @"Mozilla", nil];
        for (NSUInteger i = 0; i < [demo count]; i += 2) {
            LFTab *tab = [[LFTab alloc] init];
            [tab setUrl:[demo objectAtIndex:i]];
            [tab setTitle:[demo objectAtIndex:i + 1]];
            [_tabs addObject:tab];
            [_recent addObject:tab];
            [tab release];
        }
        [self openTabWithURL:nil];
    } else if (start || ![self restoreSession])
        [self openTabWithURL:start ? [NSString stringWithUTF8String:start] : nil];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(saveSession) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(saveSession) name:UIApplicationWillTerminateNotification object:nil];

    // Developer aid (LF_UI_STEPS in the debug file): UI actions run one
    // every 4 s after a 12 s start, for screenshots without touching the
    // device. Steps: newtab, tabs, menu, edit, back, forward, select:N,
    // memwarn, settings, passwords, testlogin, promptok, landscape, portrait,
    // wait, go:URL, snap:NAME (Library/LegacyFox/snap-NAME.png), cancel,
    // section:N (of the Awesome Screen).
    const char *steps = getenv("LF_UI_STEPS");
    if (steps) {
        NSArray *list = [[NSString stringWithUTF8String:steps] componentsSeparatedByString:@","];
        for (NSUInteger i = 0; i < [list count]; i++)
            [self performSelector:@selector(runStep:) withObject:[list objectAtIndex:i] afterDelay:12 + 4 * i];
    }
}

- (void)startSync {
    // "LegacyFox на iPad": how this device shows in Firefox elsewhere.
    NSString *device = [NSString stringWithFormat:@"LegacyFox на %@", [[UIDevice currentDevice] name]];
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:State"
                              message:[NSDictionary dictionaryWithObject:device forKey:@"deviceName"] reply:nil];
    [self watchDownloads];
}

- (void)runStep:(NSString *)step {
    if ([step isEqualToString:@"wait"]) return;
    else if ([step hasPrefix:@"snap:"]) {
        // The screen as the app would show it, for checking the interface
        // while the device's screen stays off: the page from Gecko's
        // surfaces, UIKit's windows (alerts, sheets) over it.
        UIWindow *main = [[self view] window];
        UIGraphicsBeginImageContextWithOptions([main bounds].size, YES, 0);
        CGContextRef c = UIGraphicsGetCurrentContext();
        UIView *gecko = [[_current session] view];
        BOOL page = gecko && LFSurfaceCallsReady();
        if (page) {
            CGRect r = [_pageView convertRect:[_pageView bounds] toView:main];
            CGContextSaveGState(c);
            CGContextTranslateCTM(c, r.origin.x, r.origin.y);
            [[UIColor whiteColor] setFill];
            UIRectFill(CGRectMake(0, 0, r.size.width, r.size.height));
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            LFSurfacePiece pieces[32];
            NSUInteger count = 0;
            [CATransaction lock];
            LFCollectSurfaceLayers([gecko layer], [gecko layer], pieces, &count, 32);
            [CATransaction unlock];
            for (NSUInteger i = 0; i < count; i++) {
                LFDrawSurfacePiece(c, &pieces[i], space);
                CFRelease(pieces[i].surface);
            }
            CGColorSpaceRelease(space);
            CGContextRestoreGState(c);
            [_pageView setHidden:YES];
        }
        for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
            if ([w isHidden])
                continue;
            CGContextSaveGState(c);
            CGContextTranslateCTM(c, [w frame].origin.x, [w frame].origin.y);
            [[w layer] renderInContext:c];
            CGContextRestoreGState(c);
        }
        [_pageView setHidden:NO];
        NSData *png = UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());
        UIGraphicsEndImageContext();
        [png writeToFile:[NSString stringWithFormat:@"/var/mobile/Library/LegacyFox/snap-%@.png",
                                                    [step substringFromIndex:5]] atomically:YES];
    }
    else if ([step isEqualToString:@"landscape"] || [step isEqualToString:@"portrait"]) {
        // Turns the interface as if the device had turned (private UIDevice call).
        UIDeviceOrientation o = [step isEqualToString:@"portrait"] ? UIDeviceOrientationPortrait
                                                                    : UIDeviceOrientationLandscapeLeft;
        if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)])
            [[UIDevice currentDevice] performSelector:@selector(setOrientation:) withObject:(id)(intptr_t)o];
    }
    else if ([step isEqualToString:@"newtab"]) [self newTab];
    else if ([step isEqualToString:@"cancel"]) [self hideAwesome];
    else if ([step isEqualToString:@"doorhanger"]) {
        // A password doorhanger for a made-up login, answered nowhere.
        NSDictionary *login = [NSDictionary dictionaryWithObjectsAndKeys:@"https://example.com", @"origin",
                                                                         @"user", @"username", nil];
        [self session:[_current session]
               prompt:[NSDictionary dictionaryWithObjectsAndKeys:@"Autocomplete:Save:Login", @"type", @"test", @"id",
                                                                 [NSArray arrayWithObject:login], @"logins", nil]
                reply:^(NSDictionary *r) {}];
    }
    else if ([step isEqualToString:@"find"]) [self showFindBar];
    else if ([step hasPrefix:@"section:"]) [_awesome showSection:[[step substringFromIndex:8] intValue]];
    else if ([step isEqualToString:@"tabs"]) [self topBar:_topBar tabs:[_topBar tabsItem]];
    else if ([step isEqualToString:@"menu"]) [self showMenuFrom:nil];
    else if ([step isEqualToString:@"edit"]) [self showAwesomeScreen];
    else if ([step isEqualToString:@"bookmarks"]) [self topBar:_topBar bookmarks:nil];
    else if ([step isEqualToString:@"back"]) [self goBack];
    else if ([step isEqualToString:@"forward"]) [self goForward];
    else if ([step hasPrefix:@"select:"]) [self selectTab:[_tabs objectAtIndex:[[step substringFromIndex:7] intValue]]];
    else if ([step isEqualToString:@"memwarn"]) [self didReceiveMemoryWarning];
    else if ([step isEqualToString:@"settings"]) [self showSettings];
    else if ([step isEqualToString:@"desktop"]) [[_current session] setDesktopMode:YES];
    else if ([step isEqualToString:@"private"]) [self newPrivateTab];
    else if ([step isEqualToString:@"promptok"]) [_prompter confirmForTesting];
    else if ([step isEqualToString:@"passwords"]) [self showSettings:YES];
    else if ([step isEqualToString:@"account"]) [self showAccount];
    else if ([step isEqualToString:@"tapsignin"]) {
        // The account screen's first row, as a finger would press it.
        UINavigationController *nav = (UINavigationController *)[self modalViewController];
        UITableViewController *top = (UITableViewController *)[nav topViewController];
        NSIndexPath *first = [NSIndexPath indexPathForRow:0 inSection:0];
        [[top tableView] selectRowAtIndexPath:first animated:NO scrollPosition:UITableViewScrollPositionNone];
        [top tableView:[top tableView] didSelectRowAtIndexPath:first];
    }
    else if ([step isEqualToString:@"signin"])
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:SignInURL" message:nil reply:^(id url, id error) {
            if ([url isKindOfClass:[NSString class]])
                [self openTabWithURL:url];
        }];
    else if ([step isEqualToString:@"testlogin"])
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Logins:Add"
                                  message:[NSDictionary dictionaryWithObjectsAndKeys:@"https://example.com", @"origin",
                                              @"user", @"username", @"test", @"password", nil]
                                    reply:^(id result, id error) {
                                        fprintf(stderr, "LegacyFox: test login %s %s\n", [[result description] UTF8String],
                                                [[error description] UTF8String]);
                                    }];
    else if ([step hasPrefix:@"go:"]) [self topBar:_topBar submit:[step substringFromIndex:3]];
}

// ---- the tabs of the last run ----

- (NSString *)sessionPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LegacyFox/session.plist"];
}

// Property lists hold no null: Gecko's state has some (JSON null).
static id LFPlistSafe(id value) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in value) {
            id v = LFPlistSafe([value objectForKey:key]);
            if (v && [key isKindOfClass:[NSString class]])
                [d setObject:v forKey:key];
        }
        return d;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id item in value) {
            id v = LFPlistSafe(item);
            if (v)
                [a addObject:v];
        }
        return a;
    }
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]] ||
        [value isKindOfClass:[NSDate class]] || [value isKindOfClass:[NSData class]])
        return value;
    return nil;
}

// Tabs come back after a restart, as in Firefox; private ones never do.
- (void)saveSession {
    if (getenv("LF_DEMO"))
        return;
    NSMutableArray *tabs = [NSMutableArray array];
    NSUInteger selected = 0;
    for (LFTab *tab in _tabs) {
        // Private tabs and pages that are not web pages stay out.
        // Account sign-in pages neither: their sign-in flow ends with the run.
        if ([tab privateTab] || ([[tab url] length] && ![[tab url] hasPrefix:@"http"]) ||
            [[[NSURL URLWithString:[tab url]] host] isEqualToString:@"accounts.firefox.com"])
            continue;
        if (tab == _current)
            selected = [tabs count];
        [tabs addObject:LFPlistSafe([tab archive])];
    }
    NSDictionary *session = [NSDictionary dictionaryWithObjectsAndKeys:
        tabs, @"tabs", [NSNumber numberWithUnsignedInteger:selected], @"selected", nil];
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:session
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                    errorDescription:NULL];
    [data writeToFile:[self sessionPath] atomically:YES];
}

- (BOOL)restoreSession {
    NSData *data = [NSData dataWithContentsOfFile:[self sessionPath]];
    NSDictionary *session = data ? [NSPropertyListSerialization propertyListFromData:data
                                                                     mutabilityOption:NSPropertyListImmutable
                                                                               format:NULL errorDescription:NULL] : nil;
    NSArray *tabs = [session isKindOfClass:[NSDictionary class]] ? [session objectForKey:@"tabs"] : nil;
    if (![tabs isKindOfClass:[NSArray class]] || ![tabs count])
        return NO;
    for (NSDictionary *d in tabs) {
        if (![d isKindOfClass:[NSDictionary class]])
            continue;
        LFTab *tab = [[LFTab alloc] initWithArchive:d];
        [_tabs addObject:tab];
        [tab release];
    }
    if (![_tabs count])
        return NO;
    NSUInteger selected = MIN([[session objectForKey:@"selected"] unsignedIntegerValue], [_tabs count] - 1);
    // Only the chosen tab loads; the others wait to be chosen.
    for (LFTab *tab in _tabs)
        [_recent addObject:tab];
    [self selectTab:[_tabs objectAtIndex:selected]];
    return YES;
}

- (void)newPrivateTab {
    LFTab *tab = [[LFTab alloc] init];
    [tab setPrivateTab:YES];
    [_tabs addObject:tab];
    [tab release];
    [self selectTab:tab];
    [self showAwesomeScreen];
}

// ---- thumbnails ----

// Gecko draws through layers whose contents are IOSurfaces, which
// renderInContext: leaves blank: their pixels are read here directly.
// IOSurface is a private framework before iOS 10, so its calls are looked up.
typedef struct __IOSurface *LFSurfaceRef;
static struct {
    CFTypeID (*typeID)(void);
    int (*lock)(LFSurfaceRef, uint32_t, uint32_t *);
    int (*unlock)(LFSurfaceRef, uint32_t, uint32_t *);
    void *(*base)(LFSurfaceRef);
    size_t (*bytesPerRow)(LFSurfaceRef);
    size_t (*width)(LFSurfaceRef);
    size_t (*height)(LFSurfaceRef);
} sSurface;

static BOOL LFSurfaceCallsReady(void) {
    static int ready = -1;
    if (ready < 0) {
        void *h = dlopen("/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface", RTLD_LAZY);
        if (!h)
            h = dlopen("/System/Library/Frameworks/IOSurface.framework/IOSurface", RTLD_LAZY);
        sSurface.typeID = (CFTypeID (*)(void))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceGetTypeID");
        sSurface.lock = (int (*)(LFSurfaceRef, uint32_t, uint32_t *))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceLock");
        sSurface.unlock = (int (*)(LFSurfaceRef, uint32_t, uint32_t *))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceUnlock");
        sSurface.base = (void *(*)(LFSurfaceRef))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceGetBaseAddress");
        sSurface.bytesPerRow = (size_t (*)(LFSurfaceRef))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceGetBytesPerRow");
        sSurface.width = (size_t (*)(LFSurfaceRef))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceGetWidth");
        sSurface.height = (size_t (*)(LFSurfaceRef))dlsym(h ?: RTLD_DEFAULT, "IOSurfaceGetHeight");
        ready = sSurface.typeID && sSurface.lock && sSurface.unlock && sSurface.base && sSurface.bytesPerRow &&
                sSurface.width && sSurface.height;
    }
    return ready;
}

// One surface-backed layer, found while Core Animation was locked.
typedef struct {
    LFSurfaceRef surface;  // retained
    CGRect clip;           // what shows of it, in root's coordinates
    CGRect whole;          // the whole surface, in root's coordinates
} LFSurfacePiece;

// Collects the surface-backed layers under layer. Gecko's compositor thread
// changes these layers while the main thread runs: the caller holds the
// Core Animation lock, and the surfaces are retained before it is let go.
static void LFCollectSurfaceLayers(CALayer *layer, CALayer *root, LFSurfacePiece *pieces, NSUInteger *count,
                                   NSUInteger max) {
    if ([layer isHidden] || [layer opacity] <= 0 || *count >= max)
        return;
    id contents = [layer contents];
    if (contents && CFGetTypeID((CFTypeRef)contents) == sSurface.typeID()) {
        LFSurfaceRef surface = (LFSurfaceRef)contents;
        CGRect clip = [layer convertRect:[layer bounds] toLayer:root];
        for (CALayer *l = layer; l && l != root; l = [l superlayer])
            if ([l masksToBounds])
                clip = CGRectIntersection(clip, [l convertRect:[l bounds] toLayer:root]);
        if (!CGRectIsEmpty(clip)) {
            // Contents sit at the layer's top left, one surface pixel to
            // contentsScale of a point.
            CGFloat scale = [layer contentsScale] ?: 1;
            CGRect size = CGRectMake(0, 0, sSurface.width(surface) / scale, sSurface.height(surface) / scale);
            LFSurfacePiece piece = {(LFSurfaceRef)CFRetain(surface), clip, [layer convertRect:size toLayer:root]};
            pieces[(*count)++] = piece;
        }
    }
    for (CALayer *sub in [layer sublayers])
        LFCollectSurfaceLayers(sub, root, pieces, count, max);
}

// Draws a piece into c, whose coordinates are root's (top-left origin).
static void LFDrawSurfacePiece(CGContextRef c, LFSurfacePiece *piece, CGColorSpaceRef space) {
    LFSurfaceRef surface = piece->surface;
    if (sSurface.lock(surface, 1 /* read only */, NULL) != 0)
        return;
    CGContextRef src = CGBitmapContextCreate(sSurface.base(surface), sSurface.width(surface), sSurface.height(surface),
                                             8, sSurface.bytesPerRow(surface), space,
                                             kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = src ? CGBitmapContextCreateImage(src) : NULL;
    sSurface.unlock(surface, 1, NULL);
    if (image) {
        CGRect whole = piece->whole;
        CGContextSaveGState(c);
        CGContextClipToRect(c, piece->clip);
        CGContextTranslateCTM(c, whole.origin.x, whole.origin.y + whole.size.height);
        CGContextScaleCTM(c, 1, -1);
        CGContextDrawImage(c, CGRectMake(0, 0, whole.size.width, whole.size.height), image);
        CGContextRestoreGState(c);
        CGImageRelease(image);
    }
    if (src)
        CGContextRelease(src);
}

- (void)captureThumbnail {
    UIView *view = [[_current session] view];
    if (!view || [_topBar isEditing] || [self modalViewController] || !LFSurfaceCallsReady())
        return;
    // The top of the page in the shape of Firefox's tab pictures
    // (tab_thumbnail_width x height: 136 x 78), at twice their size.
    CGRect b = [view bounds];
    CGFloat w = b.size.width;
    CGRect area = CGRectMake(0, 0, w, MIN(w * 78 / 136, b.size.height));
    if (area.size.width < 1 || area.size.height < 1)
        return;
    CGSize size = CGSizeMake(272, 156);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, space,
                                           kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    if (c) {
        CGContextSetRGBFillColor(c, 1, 1, 1, 1);
        CGContextFillRect(c, CGRectMake(0, 0, size.width, size.height));
        CGContextSetInterpolationQuality(c, kCGInterpolationMedium);
        // Layer coordinates (top-left origin) onto the bitmap.
        CGContextTranslateCTM(c, 0, size.height);
        CGContextScaleCTM(c, size.width / area.size.width, -size.height / area.size.height);
        LFSurfacePiece pieces[32];
        NSUInteger count = 0;
        [CATransaction lock];
        LFCollectSurfaceLayers([view layer], [view layer], pieces, &count, 32);
        [CATransaction unlock];
        for (NSUInteger i = 0; i < count; i++) {
            LFDrawSurfacePiece(c, &pieces[i], space);
            CFRelease(pieces[i].surface);
        }
        CGImageRef image = CGBitmapContextCreateImage(c);
        if (image) {
            UIImage *thumb = [UIImage imageWithCGImage:image];
            [_current setThumbnail:thumb];
            // Top Sites on about:home show the same pictures.
            if (![_current privateTab])
                [LFThumbnails save:thumb forURL:[_current url]];
            CGImageRelease(image);
        }
        CGContextRelease(c);
    }
    CGColorSpaceRelease(space);
}

// ---- tabs ----

- (LFTab *)tabForSession:(LFGeckoSession *)session {
    for (LFTab *tab in _tabs)
        if ([tab session] == session)
            return tab;
    return nil;
}

- (void)openTabWithURL:(NSString *)url {
    LFTab *tab = [[LFTab alloc] init];
    [tab setUrl:url];
    [_tabs addObject:tab];
    [tab release];
    [self selectTab:tab];
}

// Pages kept alive in the background besides the current one. A 512 MB
// device has room for one; the rest are reloaded when chosen.
static const NSUInteger kLiveBackgroundTabs = 1;

- (void)unloadBackgroundTabsKeeping:(NSUInteger)keep {
    // _recent: most recently used first.
    NSUInteger live = 0;
    for (LFTab *tab in [[_recent copy] autorelease]) {
        if (tab == _current || ![tab isLoaded])
            continue;
        if (live < keep)
            live++;
        else
            [tab unload];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self unloadBackgroundTabsKeeping:0];
}

- (void)selectTab:(LFTab *)tab {
    if (tab == _current)
        return;
    [self captureThumbnail];
    if (_current) {
        [[[_current session] view] removeFromSuperview];
        [[_current session] setActive:NO];
    }
    _current = tab;
    [_recent removeObject:tab];
    [_recent insertObject:tab atIndex:0];
    [self unloadBackgroundTabsKeeping:kLiveBackgroundTabs];
    [tab loadWithDelegate:self];
    [self showCurrentPage];
    [self showTabState:NO];
}

// The current tab's Gecko view, or the home page when it has none.
- (void)showCurrentPage {
    UIView *geckoView = [[_current session] view];
    for (UIView *v in [[[_pageView subviews] copy] autorelease])
        if (v != geckoView && v != _placeholder)
            [v removeFromSuperview];
    if (geckoView) {
        if ([geckoView superview] != _pageView) {
            [geckoView setFrame:[_pageView bounds]];
            [geckoView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
            [_pageView addSubview:geckoView];
        }
        [[_current session] setActive:YES];
        [_placeholder setHidden:YES];
    } else if ([_current isLoaded]) {
        [_placeholder setText:@"LegacyFox\n\nДвижок Gecko не подключён: это оболочка без движка."];
        [_placeholder setHidden:NO];
    } else {
        if (!_homeView) {
            _homeView = [[LFHomeView alloc] initWithFrame:[_pageView bounds]];
            [_homeView setHomeDelegate:self];
        }
        [_homeView reload];
        [_homeView setFrame:[_pageView bounds]];
        [_pageView addSubview:_homeView];
        [_placeholder setHidden:YES];
    }
}

// Loads url in the current tab, starting its Gecko page if it has none.
- (void)loadInCurrentTab:(NSString *)url {
    [_current setUrl:url];
    [_current setTitle:nil];
    if ([_current isLoaded]) {
        [[_current session] loadURL:url];
    } else {
        [_current loadWithDelegate:self];
        [self showCurrentPage];
    }
    [self showTabState:NO];
}

- (void)homeView:(LFHomeView *)home didChooseURL:(NSString *)url {
    [self loadInCurrentTab:url];
}

- (void)closeTab:(LFTab *)tab {
    NSUInteger index = [_tabs indexOfObject:tab];
    if (index == NSNotFound)
        return;
    if ([_tabs count] == 1) {
        // The last tab is not closed but starts over at the home page.
        [tab unload];
        [tab setUrl:nil];
        [tab setTitle:nil];
        [tab setCanGoBack:NO];
        [tab setCanGoForward:NO];
        [self showCurrentPage];
        [self showTabState:NO];
        return;
    }
    if (tab == _current) {
        NSUInteger next = index + 1 < [_tabs count] ? index + 1 : index - 1;
        [self selectTab:[_tabs objectAtIndex:next]];
    }
    [tab unload];
    [_recent removeObject:tab];
    [_tabs removeObjectAtIndex:index];
    [self showTabState:NO];
}

// The bars show the current tab.
- (void)showTabState:(BOOL)animated {
    NSString *url = [_current url];
    [_topBar setPrivate:[_current privateTab]];
    [_topBar setTitle:[_current title] url:LFDisplayURL(url)];
    [_topBar setLoading:[_current loading]];
    [_topBar setProgress:[_current loading] ? [_current progress] : 0];
    [_topBar setFavicon:[[LFStore shared] iconForURL:url]];
    [_topBar setSecure:[url hasPrefix:@"https://"]];
    [_topBar setCanGoBack:[_current canGoBack] canGoForward:[_current canGoForward]];
    [_topBar setTabCount:[_tabs count] animated:animated];
}

- (void)showFaviconFor:(NSString *)url {
    if ([[_current url] isEqualToString:url])
        [_topBar setFavicon:[[LFStore shared] iconForURL:url]];
}

// ---- layout ----

- (void)layoutMain {
    CGRect b = [[self view] bounds];
    CGFloat w = b.size.width, h = b.size.height, bar = [LFTopBar height], bottom = [LFTopBar bottomHeight];
    [_topBar setFrame:CGRectMake(0, 0, w, bar)];
    [[_topBar bottomBar] setFrame:CGRectMake(0, h - bottom, w, bottom)];
    [_pageView setFrame:CGRectMake(0, bar, w, h - bar - bottom)];
    // iPhone: the Awesome Screen covers the page while typing.
    if (![LFFennec pad] && [_awesome isViewLoaded] && [[_awesome view] superview] == [self view])
        [[_awesome view] setFrame:CGRectMake(0, bar, w, h - bar)];
    if ([_findBar superview] && ![_findBar isEditing])
        [_findBar setFrame:CGRectMake(0, h - bottom - 44, w, 44)];
}

// iPad: one popover at a time.
- (void)presentPopover:(UIViewController *)content from:(UIBarButtonItem *)item orView:(UIView *)view {
    [self dismissPopover];
    _popover = [[UIPopoverController alloc] initWithContentViewController:content];
    [_popover setDelegate:self];
    if (item)
        [_popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionUp
                                         animated:YES];
    else
        [_popover presentPopoverFromRect:[view bounds] inView:view permittedArrowDirections:UIPopoverArrowDirectionUp
                                animated:YES];
}

- (void)dismissPopover {
    [_popover setDelegate:nil];
    [_popover dismissPopoverAnimated:YES];
    [_popover release];
    _popover = nil;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover {
    if (popover == _popover) {
        [[_popover retain] autorelease];
        [_popover release];
        _popover = nil;
    }
    // A tap outside the Awesome Screen ends the typing too.
    [_topBar endEditing];
}

// ---- tabs ----

// iPhone: a screen of its own, in a navigation bar of Firefox Home's blue.
- (void)presentFullScreen:(UIViewController *)content {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:content];
    [self presentModalViewController:nav animated:YES];
    [nav release];
}

- (void)topBar:(LFTopBar *)bar tabs:(UIBarButtonItem *)item {
    [_topBar endEditing];
    [self captureThumbnail];
    if ([LFFennec pad]) {
        UIViewController *shown = [_popover contentViewController];
        if ([_popover isPopoverVisible] && [shown isKindOfClass:[UINavigationController class]] &&
            [[(UINavigationController *)shown topViewController] isKindOfClass:[LFTabsList class]]) {
            [self dismissPopover];
            return;
        }
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:_tabsList];
        [self presentPopover:nav from:item ? item : [_topBar tabsItem] orView:nil];
        [nav release];
    } else {
        [self presentFullScreen:_tabsList];
    }
}

- (void)hideTabs {
    if ([LFFennec pad])
        [self dismissPopover];
    else if ([self modalViewController])
        [self dismissModalViewControllerAnimated:YES];
}

// ---- LFTabsListDelegate ----

- (NSUInteger)numberOfTabsInList:(LFTabsList *)list { return [_tabs count]; }
- (NSString *)tabsList:(LFTabsList *)list titleAtIndex:(NSUInteger)i {
    LFTab *tab = [_tabs objectAtIndex:i];
    return [[tab title] length] ? [tab title] : [[tab url] length] ? LFDisplayURL([tab url]) : @"Новая вкладка";
}
- (NSString *)tabsList:(LFTabsList *)list urlAtIndex:(NSUInteger)i { return [(LFTab *)[_tabs objectAtIndex:i] url]; }
- (UIImage *)tabsList:(LFTabsList *)list thumbnailAtIndex:(NSUInteger)i { return [(LFTab *)[_tabs objectAtIndex:i] thumbnail]; }
- (BOOL)tabsList:(LFTabsList *)list isPrivateAtIndex:(NSUInteger)i { return [(LFTab *)[_tabs objectAtIndex:i] privateTab]; }
- (NSUInteger)selectedIndexInTabsList:(LFTabsList *)list { return [_tabs indexOfObject:_current]; }

- (void)tabsList:(LFTabsList *)list didSelectIndex:(NSUInteger)i {
    [self selectTab:[_tabs objectAtIndex:i]];
    [self hideTabs];
}

- (void)tabsList:(LFTabsList *)list didCloseIndex:(NSUInteger)i {
    if (i < [_tabs count])
        [self closeTab:[_tabs objectAtIndex:i]];
}

- (void)tabsListDidAddTab:(LFTabsList *)list {
    [self hideTabs];
    [self newTab];
}

- (void)tabsListDidFinish:(LFTabsList *)list {
    [self hideTabs];
}

- (void)newTab {
    [self openTabWithURL:nil];
    // A new tab starts with the address field ready for typing (after the
    // tabs screen has gone).
    [self performSelector:@selector(showAwesomeScreen) withObject:nil afterDelay:0.4];
}

// ---- LFTopBarDelegate ----

- (void)topBarBack:(LFTopBar *)bar { [self goBack]; }
- (void)topBarForward:(LFTopBar *)bar { [self goForward]; }
- (void)topBarReload:(LFTopBar *)bar { [[_current session] reload]; }
- (void)topBarStop:(LFTopBar *)bar { [[_current session] stop]; }
- (void)topBar:(LFTopBar *)bar action:(UIBarButtonItem *)item { [self showMenuFrom:item]; }

// The bookmarks button: the Awesome Screen's Bookmarks, without typing.
- (void)topBar:(LFTopBar *)bar bookmarks:(UIBarButtonItem *)item {
    [_topBar endEditing];
    [_awesome setQuery:nil];
    [_awesome showSection:1];
    if ([LFFennec pad]) {
        [self presentPopover:_awesome from:item orView:[_topBar fieldView]];
    } else {
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self action:@selector(dismissModal)];
        [[_awesome navigationItem] setRightBarButtonItem:done];
        [_awesome setTitle:@"Закладки"];
        [done release];
        [self presentFullScreen:_awesome];
    }
}

- (void)dismissModal {
    [self dismissModalViewControllerAnimated:YES];
}

// titlebar_contextmenu of Firefox: a long press on the address.
- (void)topBarLongPress:(LFTopBar *)bar {
    NSString *clip = [[UIPasteboard generalPasteboard] string];
    BOOL page = [[_current url] length] > 0;
    if (![clip length] && !page)
        return;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil
                                         destructiveButtonTitle:nil otherButtonTitles:nil];
    [sheet setTag:2];
    if ([clip length]) {
        [sheet addButtonWithTitle:@"Вставить и перейти"];
        [sheet addButtonWithTitle:@"Вставить"];
    }
    if (page)
        [sheet addButtonWithTitle:@"Скопировать адрес"];
    if (![LFFennec pad])
        [sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Отмена"]];
    UIView *field = [_topBar fieldView];
    [sheet showFromRect:[field bounds] inView:field animated:YES];
    [sheet release];
}

- (void)titleAction:(NSString *)title {
    NSString *clip = [[UIPasteboard generalPasteboard] string];
    if ([title isEqualToString:@"Вставить и перейти"])
        [self loadInCurrentTab:[self urlForInput:clip]];
    else if ([title isEqualToString:@"Вставить"])
        [_topBar beginEditingWithText:clip];
    else if ([title isEqualToString:@"Скопировать адрес"])
        [[UIPasteboard generalPasteboard] setString:[_current url]];
}

- (void)toggleBookmark {
    NSString *url = [_current url];
    if (![url length])
        return;
    LFStore *store = [LFStore shared];
    if ([store isBookmarked:url]) {
        [store removeBookmark:url];
        [LFNote show:@"Закладка удалена" inView:[self view]];
    } else {
        [store addBookmark:url title:[_current title]];
        [LFNote show:@"Закладка добавлена" inView:[self view]];
    }
}

// ---- menu ----

// The share button's sheet: what Firefox's menu held, in iOS's form.
- (void)showMenuFrom:(UIBarButtonItem *)item {
    [_topBar endEditing];
    [self dismissPopover];
    BOOL page = [[_current url] length] > 0 && [_current isLoaded];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil
                                         destructiveButtonTitle:nil otherButtonTitles:nil];
    if (page) {
        [sheet addButtonWithTitle:[[LFStore shared] isBookmarked:[_current url]] ? @"Удалить закладку"
                                                                                 : @"Добавить закладку"];
        [sheet addButtonWithTitle:@"Поделиться…"];
        [sheet addButtonWithTitle:@"Скопировать адрес"];
        [sheet addButtonWithTitle:@"Найти на странице"];
        [sheet addButtonWithTitle:[[_current session] desktopMode] ? @"Мобильная версия сайта"
                                                                    : @"Полная версия сайта"];
    }
    [sheet addButtonWithTitle:@"Новая приватная вкладка"];
    [sheet addButtonWithTitle:@"Загрузки"];
    [sheet addButtonWithTitle:@"Параметры"];
    if (![LFFennec pad])
        [sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Отмена"]];
    if (item)
        [sheet showFromBarButtonItem:item animated:YES];
    else
        [sheet showInView:[self view]];
    [sheet release];
}

- (void)menuAction:(NSString *)title {
    if ([title isEqualToString:@"Добавить закладку"] || [title isEqualToString:@"Удалить закладку"])
        [self toggleBookmark];
    else if ([title isEqualToString:@"Поделиться…"])
        [self share];
    else if ([title isEqualToString:@"Скопировать адрес"])
        [[UIPasteboard generalPasteboard] setString:[_current url]];
    else if ([title isEqualToString:@"Найти на странице"])
        [self showFindBar];
    else if ([title isEqualToString:@"Полная версия сайта"])
        [[_current session] setDesktopMode:YES];
    else if ([title isEqualToString:@"Мобильная версия сайта"])
        [[_current session] setDesktopMode:NO];
    else if ([title isEqualToString:@"Новая приватная вкладка"])
        [self newPrivateTab];
    else if ([title isEqualToString:@"Загрузки"])
        [self showDownloads];
    else if ([title isEqualToString:@"Параметры"])
        [self showSettings];
}

// iOS 6's share sheet; before it, the address is copied.
- (void)share {
    NSString *url = [_current url];
    if (![url length])
        return;
    Class activity = NSClassFromString(@"UIActivityViewController");
    if (!activity) {
        [[UIPasteboard generalPasteboard] setString:url];
        [LFNote show:@"Адрес скопирован" inView:[self view]];
        return;
    }
    NSArray *things = [NSArray arrayWithObject:[NSURL URLWithString:url] ?: (id)url];
    UIViewController *sheet = [[activity alloc] initWithActivityItems:things applicationActivities:nil];
    if ([LFFennec pad])
        [self presentPopover:sheet from:nil orView:[_topBar fieldView]];
    else
        [self presentModalViewController:sheet animated:YES];
    [sheet release];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == [sheet cancelButtonIndex] || index < 0)
        return;
    NSString *title = [sheet buttonTitleAtIndex:index];
    if ([sheet tag] == 1)
        [self contextAction:title];
    else if ([sheet tag] == 2)
        [self titleAction:title];
    else
        [self menuAction:title];
}

- (void)showDownloads {
    LFDownloadsController *list = [[LFDownloadsController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    [nav setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentModalViewController:nav animated:YES];
    [nav release];
    [list release];
}

- (void)watchDownloads {
    UIView *view = [self view];
    LFGeckoRuntime *runtime = [LFGeckoRuntime shared];
    [runtime addHandler:^(NSDictionary *m, id<EventCallback> cb) {
        [LFNote show:[NSString stringWithFormat:@"Загрузка: %@", [m objectForKey:@"name"]] inView:view];
        [cb sendSuccess:nil];
    } forType:@"LegacyFox:Downloads:Started"];
    [runtime addHandler:^(NSDictionary *m, id<EventCallback> cb) {
        [LFNote show:[NSString stringWithFormat:@"Скачано: %@", [m objectForKey:@"name"]] inView:view];
        [cb sendSuccess:nil];
    } forType:@"LegacyFox:Downloads:Finished"];
    // The list call starts Gecko's side watching.
    [runtime dispatch:@"LegacyFox:Downloads:List" message:nil reply:nil];
}

- (void)showAccount {
    [self showSettings:NO];
    UINavigationController *nav = (UINavigationController *)[self modalViewController];
    LFAccountController *account = [[LFAccountController alloc] init];
    LFBrowserViewController *browser = self;
    [account setOpenURL:^(NSString *url) {
        [browser openTabWithURL:url];
    }];
    [nav pushViewController:account animated:NO];
    [account release];
}

- (void)showSettings {
    [self showSettings:NO];
}

- (void)showSettings:(BOOL)passwords {
    LFSettingsController *settings = [[LFSettingsController alloc] init];
    LFBrowserViewController *browser = self;
    [settings setOpenURL:^(NSString *url) {
        [browser openTabWithURL:url];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    [nav setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentModalViewController:nav animated:YES];
    if (passwords) {
        LFPasswordsController *list = [[LFPasswordsController alloc] init];
        [nav pushViewController:list animated:NO];
        [list release];
    }
    [nav release];
    [settings release];
}

// ---- Awesome Screen ----

- (NSString *)urlForInput:(NSString *)text {
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([text rangeOfString:@"://"].location != NSNotFound || [text hasPrefix:@"about:"] || [text hasPrefix:@"data:"])
        return text;
    if ([text rangeOfString:@" "].location == NSNotFound && [text rangeOfString:@"."].location != NSNotFound)
        return [@"https://" stringByAppendingString:text];
    return [LFSettings searchURLFor:text];
}

- (void)showAwesomeScreen {
    [_topBar beginEditingWithText:[_current url] ? LFDisplayURL([_current url]) : nil];
}

- (void)topBarDidBeginEditing:(LFTopBar *)bar {
    [_awesome setQuery:nil];
    [_awesome showSection:0];
    [_awesome setTitle:nil];
    [[_awesome navigationItem] setRightBarButtonItem:nil];
    if ([LFFennec pad]) {
        [self presentPopover:_awesome from:nil orView:[_topBar fieldView]];
        // Typing goes on in the bar while the popover shows.
        [_popover setPassthroughViews:[NSArray arrayWithObject:_topBar]];
    } else {
        CGRect b = [[self view] bounds];
        [[_awesome view] setFrame:CGRectMake(0, [LFTopBar height], b.size.width, b.size.height - [LFTopBar height])];
        [[self view] addSubview:[_awesome view]];
    }
}

- (void)topBarDidEndEditing:(LFTopBar *)bar {
    if ([LFFennec pad]) {
        if ([_popover contentViewController] == _awesome)
            [self dismissPopover];
    } else if ([[_awesome view] superview] == [self view]) {
        [[_awesome view] removeFromSuperview];
    }
}

- (void)topBar:(LFTopBar *)bar textChanged:(NSString *)text {
    [_awesome setQuery:text];
}

- (void)topBar:(LFTopBar *)bar submit:(NSString *)text {
    [_topBar endEditing];
    [self loadInCurrentTab:[self urlForInput:text]];
}

- (void)hideAwesome {
    [_topBar endEditing];
    [self dismissPopover];
    if ([self modalViewController])
        [self dismissModalViewControllerAnimated:YES];
}

- (void)awesomeController:(LFAwesomeController *)awesome didChooseURL:(NSString *)url {
    [self hideAwesome];
    [self loadInCurrentTab:url];
}

- (void)awesomeController:(LFAwesomeController *)awesome didSearch:(NSString *)text {
    [self hideAwesome];
    [self loadInCurrentTab:[LFSettings searchURLFor:text]];
}

// ---- about:home ----

- (void)homeViewShowAllTopSites:(LFHomeView *)home {
    [self showAwesomeScreen];
}

- (void)homeViewSignIn:(LFHomeView *)home {
    [self showAccount];
}

// ---- LFGeckoSessionDelegate ----

- (void)session:(LFGeckoSession *)session locationChanged:(NSString *)url
      canGoBack:(BOOL)back canGoForward:(BOOL)forward {
    LFTab *tab = [self tabForSession:session];
    // The title is reset on page start, not here: pages also change their
    // address with history.replaceState and keep their title.
    // A new page reports its first, empty document before the address it
    // was opened for: the bar keeps showing that address meanwhile.
    BOOL initialBlank = [url isEqualToString:@"about:blank"] && [[tab url] length] &&
                        ![[tab url] isEqualToString:@"about:blank"];
    if (url && !initialBlank)
        [tab setUrl:url];
    [tab setCanGoBack:back];
    [tab setCanGoForward:forward];
    if (tab == _current)
        [self showTabState:YES];
}

- (void)session:(LFGeckoSession *)session titleChanged:(NSString *)title {
    LFTab *tab = [self tabForSession:session];
    [tab setTitle:[title isKindOfClass:[NSString class]] ? title : nil];
    if (tab == _current)
        [_topBar setTitle:[tab title] url:LFDisplayURL([tab url])];
    if ([_tabsList isViewLoaded] && [[_tabsList view] window])
        [_tabsList reload];
}

- (void)sessionPageStarted:(LFGeckoSession *)session {
    LFTab *tab = [self tabForSession:session];
    [tab setLoading:YES];
    [tab setProgress:0.05f];
    [tab setTitle:nil];
    if (tab == _current)
        [self showTabState:NO];
}

- (void)session:(LFGeckoSession *)session progressChanged:(float)progress {
    LFTab *tab = [self tabForSession:session];
    [tab setProgress:progress];
}

- (void)session:(LFGeckoSession *)session pageStopped:(BOOL)success {
    LFTab *tab = [self tabForSession:session];
    [tab setLoading:NO];
    [tab setProgress:0];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveSession) object:nil];
    [self performSelector:@selector(saveSession) withObject:nil afterDelay:2];
    if (tab == _current) {
        [self showTabState:NO];
        // Its icon, once Places has it.
        NSString *url = [tab url];
        if ([url hasPrefix:@"http"] && ![tab privateTab]) {
            LFBrowserViewController *me = self;
            [[LFStore shared] fetchIconForPage:url done:^(UIImage *icon) {
                [me showFaviconFor:url];
            }];
        }
        // The finished page for the tabs panel, once it has been painted.
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(captureThumbnail) object:nil];
        [self performSelector:@selector(captureThumbnail) withObject:nil afterDelay:1.5];
    }
}

// Dialogs from pages, one at a time. A background tab's dialog is shown
// too: its page cannot go on until it is answered.
- (void)session:(LFGeckoSession *)session prompt:(NSDictionary *)prompt
          reply:(void (^)(NSDictionary *))reply {
    if (!_prompter)
        _prompter = [[LFPrompter alloc] initWithHostController:self];
    [_prompter showPrompt:prompt reply:reply];
}

// ---- long press on links and images ----

static NSString *LFStr(id v) { return [v isKindOfClass:[NSString class]] && [v length] ? v : nil; }

- (void)session:(LFGeckoSession *)session contextMenu:(NSDictionary *)info {
    NSString *link = LFStr([info objectForKey:@"uri"]);
    NSString *image = LFStr([info objectForKey:@"elementSrc"]);
    if (!link && !image)
        return;
    [_contextInfo release];
    _contextInfo = [info retain];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LFDisplayURL(link ? link : image) delegate:self
                                              cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [sheet setTag:1];
    if (link) {
        [sheet addButtonWithTitle:@"Открыть в новой вкладке"];
        [sheet addButtonWithTitle:@"Скопировать ссылку"];
    }
    if (image) {
        [sheet addButtonWithTitle:@"Открыть изображение"];
        [sheet addButtonWithTitle:@"Сохранить изображение"];
    }
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
        [sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Отмена"]];
    // On the iPad, a popover where the finger is.
    CGPoint p = CGPointMake([[info objectForKey:@"screenX"] floatValue], [[info objectForKey:@"screenY"] floatValue]);
    p = [_pageView convertPoint:p toView:[self view]];
    [sheet showFromRect:CGRectMake(p.x - 1, p.y - 1, 2, 2) inView:[self view] animated:YES];
    [sheet release];
}

- (void)contextAction:(NSString *)title {
    NSString *link = LFStr([_contextInfo objectForKey:@"uri"]);
    NSString *image = LFStr([_contextInfo objectForKey:@"elementSrc"]);
    if ([title isEqualToString:@"Открыть в новой вкладке"])
        [self openBackgroundTab:link];
    else if ([title isEqualToString:@"Скопировать ссылку"])
        [[UIPasteboard generalPasteboard] setString:link];
    else if ([title isEqualToString:@"Открыть изображение"])
        [self loadInCurrentTab:image];
    else if ([title isEqualToString:@"Сохранить изображение"])
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Downloads:Save"
                                  message:[NSDictionary dictionaryWithObject:image forKey:@"url"] reply:nil];
}

// Firefox opened links from the menu behind the current tab.
- (void)openBackgroundTab:(NSString *)url {
    LFTab *tab = [[LFTab alloc] init];
    [tab setUrl:url];
    [_tabs insertObject:tab atIndex:[_tabs indexOfObject:_current] + 1];
    [_recent addObject:tab];
    [tab release];
    [_topBar setTabCount:[_tabs count] animated:YES];
    [LFNote show:@"Открыто в новой вкладке" inView:[self view]];
}

// Links opening a new window become a new tab in front, as in Firefox.
- (LFGeckoSession *)session:(LFGeckoSession *)session newSessionWithId:(NSString *)newSessionId
                        uri:(NSString *)uri {
    LFTab *tab = [[LFTab alloc] initWithOpenedSessionId:newSessionId delegate:self];
    if ([uri isKindOfClass:[NSString class]] && [uri length])
        [tab setUrl:uri];
    NSUInteger index = [_tabs indexOfObject:[self tabForSession:session]];
    [_tabs insertObject:tab atIndex:index == NSNotFound ? [_tabs count] : index + 1];
    [tab release];
    [self selectTab:tab];
    return [tab session];
}

- (void)session:(LFGeckoSession *)session dismissPrompt:(NSString *)promptId {
    [_prompter dismissPrompt:promptId];
}

// ---- find in page ----

- (void)showFindBar {
    CGRect b = [[self view] bounds];
    if (!_findBar) {
        _findBar = [[LFFindBar alloc] initWithFrame:CGRectMake(0, b.size.height - [LFTopBar height], b.size.width, [LFTopBar height])];
        [_findBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
        [_findBar setDelegate:self];
        // Rides up with the keyboard.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardMoved:)
                                                     name:UIKeyboardWillChangeFrameNotification object:nil];
    }
    [_findBar setFrame:CGRectMake(0, b.size.height - [LFTopBar height], b.size.width, [LFTopBar height])];
    [[self view] addSubview:_findBar];
    [_findBar beginEditing];
}

- (void)keyboardMoved:(NSNotification *)note {
    if (![_findBar superview])
        return;
    CGRect kb = [[self view] convertRect:[[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue]
                                fromView:nil];
    CGRect b = [[self view] bounds];
    CGFloat bottom = MIN(b.size.height - [LFTopBar bottomHeight], kb.origin.y);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.25];
    [_findBar setFrame:CGRectMake(0, bottom - [LFTopBar height], b.size.width, [LFTopBar height])];
    [UIView commitAnimations];
}

- (void)findBar:(LFFindBar *)bar find:(NSString *)text backwards:(BOOL)backwards {
    if (text && ![text length]) {
        [[_current session] clearMatches];
        [bar setCurrent:0 total:0 found:YES];
        return;
    }
    [[_current session] find:text backwards:backwards reply:^(id result, id error) {
        if (![result isKindOfClass:[NSDictionary class]])
            return;
        [bar setCurrent:[[result objectForKey:@"current"] intValue] total:[[result objectForKey:@"total"] intValue]
                  found:[[result objectForKey:@"found"] boolValue]];
    }];
}

- (void)findBarDidClose:(LFFindBar *)bar {
    [[_current session] clearMatches];
    [bar removeFromSuperview];
}

// ---- navigation ----

- (void)goBack { [[_current session] goBack]; }
- (void)goForward { [[_current session] goForward]; }

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // Upside down only on the iPad, as the system apps do it.
    return orientation != UIInterfaceOrientationPortraitUpsideDown ||
           UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [self layoutMain];
}

// iOS 5 and later lay the root view out after it changes size.
- (void)viewWillLayoutSubviews {
    [self layoutMain];
}

- (void)dealloc {
    for (LFTab *tab in _tabs)
        [[tab session] setDelegate:nil];
    [_tabs release];
    [_recent release];
    [_tabsList setDelegate:nil];
    [_tabsList release];
    [_awesome setDelegate:nil];
    [_awesome release];
    [_popover setDelegate:nil];
    [_popover release];
    [_homeView release];
    [_prompter release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_findBar setDelegate:nil];
    [_findBar release];
    [_contextInfo release];
    [_topBar release];
    [_pageView release];
    [_placeholder release];
    [super dealloc];
}

@end
