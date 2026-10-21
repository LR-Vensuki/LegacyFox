#import "LFStore.h"
#import "Gecko/LFGecko.h"

@implementation LFSite

@synthesize url = _url;
@synthesize title = _title;
@synthesize visits = _visits;
@synthesize lastVisit = _lastVisit;

- (NSString *)displayTitle {
    // Pages without a <title> get their address as one.
    if ([_title length] && ![_title hasPrefix:@"http://"] && ![_title hasPrefix:@"https://"])
        return _title;
    NSString *host = [[NSURL URLWithString:_url] host];
    if ([host hasPrefix:@"www."])
        host = [host substringFromIndex:4];
    return [host length] ? host : _url;
}

+ (NSArray *)sitesFrom:(id)result {
    NSMutableArray *sites = [NSMutableArray array];
    if (![result isKindOfClass:[NSArray class]])
        return sites;
    for (NSDictionary *d in result) {
        if (![d isKindOfClass:[NSDictionary class]] || ![[d objectForKey:@"url"] isKindOfClass:[NSString class]])
            continue;
        LFSite *site = [[LFSite alloc] init];
        [site setUrl:[d objectForKey:@"url"]];
        id title = [d objectForKey:@"title"];
        [site setTitle:[title isKindOfClass:[NSString class]] ? title : nil];
        [site setVisits:[[d objectForKey:@"visits"] unsignedIntegerValue]];
        [site setLastVisit:[[d objectForKey:@"lastVisit"] doubleValue] / 1000];
        [sites addObject:site];
        [site release];
    }
    return sites;
}

- (void)dealloc {
    [_url release];
    [_title release];
    [super dealloc];
}

@end

@implementation LFStore

+ (LFStore *)shared {
    static LFStore *store;
    if (!store)
        store = [[LFStore alloc] init];
    return store;
}

- (id)init {
    if ((self = [super init])) {
        _bookmarked = [[NSMutableSet alloc] init];
        _icons = [[NSMutableDictionary alloc] init];
    }
    return self;
}

// data:...;base64,... (NSData learnt base64 only in iOS 7).
static NSData *LFDataFromDataURI(NSString *uri) {
    NSRange comma = [uri rangeOfString:@","];
    if (![uri hasPrefix:@"data:"] || comma.location == NSNotFound)
        return nil;
    NSString *head = [uri substringToIndex:comma.location];
    NSString *body = [uri substringFromIndex:comma.location + 1];
    if ([head rangeOfString:@";base64"].location == NSNotFound)
        return [[body stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding];
    static signed char map[256];
    static BOOL ready;
    if (!ready) {
        memset(map, -1, sizeof(map));
        const char *abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        for (int i = 0; i < 64; i++)
            map[(unsigned char)abc[i]] = (signed char)i;
        ready = YES;
    }
    const char *in = [body UTF8String];
    NSMutableData *out = [NSMutableData dataWithCapacity:strlen(in) * 3 / 4];
    unsigned acc = 0;
    int bits = 0;
    for (; *in; in++) {
        signed char v = map[(unsigned char)*in];
        if (v < 0)
            continue;
        acc = (acc << 6) | (unsigned)v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            unsigned char byte = (unsigned char)((acc >> bits) & 0xff);
            [out appendBytes:&byte length:1];
        }
    }
    return out;
}

- (UIImage *)iconForURL:(NSString *)url {
    if (getenv("LF_DEMO"))
        return nil;
    id icon = url ? [_icons objectForKey:url] : nil;
    return [icon isKindOfClass:[UIImage class]] ? icon : nil;
}

- (void)forgetIconForURL:(NSString *)url {
    if (url)
        [_icons removeObjectForKey:url];
}

- (void)fetchIconForPage:(NSString *)url done:(void (^)(UIImage *))done {
    void (^finished)(UIImage *) = [[done copy] autorelease];
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Places:FetchIcon"
                              message:[NSDictionary dictionaryWithObject:url forKey:@"url"]
                                reply:^(id result, id error) {
        NSData *data = [result isKindOfClass:[NSString class]] ? LFDataFromDataURI(result) : nil;
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        if (getenv("LF_UI_STEPS"))
            fprintf(stderr, "LegacyFox: icon for %s: %u bytes %s\n", [url UTF8String], (unsigned)[data length],
                    [[result description] length] > 40 ? [[[result description] substringToIndex:40] UTF8String] : "-");
        if (image)
            [_icons setObject:image forKey:url];
        if (finished)
            finished(image);
    }];
}

- (void)loadIcons:(NSArray *)urls done:(void (^)(void))done {
    if (getenv("LF_DEMO"))
        return;
    NSMutableArray *missing = [NSMutableArray array];
    for (NSString *url in urls)
        if ([url isKindOfClass:[NSString class]] && ![_icons objectForKey:url]) {
            [missing addObject:url];
            [_icons setObject:[NSNull null] forKey:url];
        }
    if (![missing count])
        return;
    CGFloat scale = [[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1;
    NSDictionary *message = [NSDictionary dictionaryWithObjectsAndKeys:
        missing, @"urls", [NSNumber numberWithInt:(int)(32 * scale)], @"size", nil];
    void (^finished)(void) = [[done copy] autorelease];
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Places:Favicons" message:message reply:^(id result, id error) {
        if (![result isKindOfClass:[NSDictionary class]])
            return;
        BOOL any = NO;
        for (NSString *url in result) {
            NSData *data = LFDataFromDataURI([result objectForKey:url]);
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            if (image) {
                [_icons setObject:image forKey:url];
                any = YES;
            }
        }
        if (any && finished)
            finished();
    }];
}

// Places can be slow to answer while Sync writes to it (seconds, right
// after start): lists show the last answer at once, then the new one.
// Top Sites are also kept on disk for the first screen after a start.
- (NSString *)cachePath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/LegacyFox/places-lists.plist"];
}

// Developer aid (LF_DEMO in the debug file): made-up lists instead of the
// user's own, for pictures of the interface.
static NSArray *LFDemoSites(NSString *event) {
    NSArray *all = [NSArray arrayWithObjects:
        @"https://ru.wikipedia.org/", @"Википедия — свободная энциклопедия",
        @"https://ya.ru/", @"Яндекс",
        @"https://www.mozilla.org/ru/", @"Mozilla",
        @"https://m.youtube.com/", @"YouTube",
        @"https://github.com/", @"GitHub",
        @"https://habr.com/ru/", @"Хабр",
        @"https://www.reddit.com/r/jailbreak/", @"r/jailbreak",
        @"https://news.ycombinator.com/", @"Hacker News",
        @"https://addons.mozilla.org/ru/firefox/", @"Дополнения Firefox",
        @"https://www.openstreetmap.org/", @"OpenStreetMap",
        @"https://archive.org/", @"Internet Archive",
        @"https://www.theverge.com/", @"The Verge", nil];
    NSMutableArray *sites = [NSMutableArray array];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL bookmarks = [event hasSuffix:@"Bookmarks"];
    for (NSUInteger i = bookmarks ? 4 : 0; i + 1 < [all count]; i += 2)
        [sites addObject:[NSDictionary dictionaryWithObjectsAndKeys:[all objectAtIndex:i], @"url",
            [all objectAtIndex:i + 1], @"title", [NSNumber numberWithDouble:(now - i * 30000) * 1000], @"lastVisit", nil]];
    return sites;
}

- (void)ask:(NSString *)event message:(NSDictionary *)message done:(LFSitesBlock)done {
    LFSitesBlock block = [[done copy] autorelease];
    if (getenv("LF_DEMO")) {
        if (block)
            block([LFSite sitesFrom:LFDemoSites(event)]);
        return;
    }
    if (!_lists) {
        _lists = [[NSMutableDictionary alloc] initWithContentsOfFile:[self cachePath]];
        if (!_lists)
            _lists = [[NSMutableDictionary alloc] init];
    }
    NSString *key = [NSString stringWithFormat:@"%@ %@", event, [message objectForKey:@"limit"]];
    id cached = [_lists objectForKey:key];
    if (cached && block && ![message objectForKey:@"text"])
        block([LFSite sitesFrom:cached]);
    CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
    [[LFGeckoRuntime shared] dispatch:event message:message reply:^(id result, id error) {
        if (getenv("LF_UI_STEPS"))
            fprintf(stderr, "LegacyFox: %s answered in %.0f ms\n", [key UTF8String], (CFAbsoluteTimeGetCurrent() - t0) * 1000);
        if ([result isKindOfClass:[NSArray class]] && ![message objectForKey:@"text"]) {
            if ([result isEqual:[_lists objectForKey:key]])
                return;
            [_lists setObject:result forKey:key];
            if ([event hasSuffix:@"TopSites"]) {
                NSMutableDictionary *disk = [NSMutableDictionary dictionary];
                for (NSString *k in _lists)
                    if ([k hasPrefix:@"LegacyFox:Places:TopSites"])
                        [disk setObject:[_lists objectForKey:k] forKey:k];
                [[NSFileManager defaultManager] createDirectoryAtPath:[[self cachePath] stringByDeletingLastPathComponent]
                                          withIntermediateDirectories:YES attributes:nil error:NULL];
                [disk writeToFile:[self cachePath] atomically:YES];
            }
        }
        if (block)
            block([LFSite sitesFrom:result]);
    }];
}

+ (NSDictionary *)limit:(NSUInteger)limit {
    return [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger:limit] forKey:@"limit"];
}

- (void)topSites:(NSUInteger)limit done:(LFSitesBlock)done {
    // One tile per site: the most frecent page of each host.
    LFSitesBlock block = [[done copy] autorelease];
    [self ask:@"LegacyFox:Places:TopSites" message:[LFStore limit:limit * 4] done:^(NSArray *sites) {
        NSMutableArray *top = [NSMutableArray array];
        NSMutableSet *hosts = [NSMutableSet set];
        for (LFSite *s in sites) {
            NSString *host = [[NSURL URLWithString:[s url]] host];
            if (!host || [hosts containsObject:host])
                continue;
            [hosts addObject:host];
            [top addObject:s];
            if ([top count] == limit)
                break;
        }
        block(top);
    }];
}

- (void)history:(NSUInteger)limit done:(LFSitesBlock)done {
    [self ask:@"LegacyFox:Places:History" message:[LFStore limit:limit] done:done];
}

- (void)refreshBookmarks {
    [self ask:@"LegacyFox:Places:Bookmarks" message:[LFStore limit:5000] done:^(NSArray *sites) {
        [_bookmarked removeAllObjects];
        for (LFSite *s in sites)
            [_bookmarked addObject:[s url]];
    }];
}

- (void)bookmarks:(NSUInteger)limit done:(LFSitesBlock)done {
    [self ask:@"LegacyFox:Places:Bookmarks" message:[LFStore limit:limit] done:done];
}

- (void)matches:(NSString *)text limit:(NSUInteger)limit done:(LFSitesBlock)done {
    [self ask:@"LegacyFox:Places:Search"
      message:[NSDictionary dictionaryWithObjectsAndKeys:text ? text : @"", @"text",
                               [NSNumber numberWithUnsignedInteger:limit], @"limit", nil]
         done:done];
}

- (BOOL)isBookmarked:(NSString *)url {
    if (getenv("LF_DEMO")) {
        // Nothing from the user's profile: the made-up bookmarks only.
        for (NSDictionary *d in LFDemoSites(@"Bookmarks"))
            if ([[d objectForKey:@"url"] isEqualToString:url])
                return YES;
        return NO;
    }
    return url && [_bookmarked containsObject:url];
}

- (void)change:(NSString *)event message:(NSDictionary *)message {
    [[LFGeckoRuntime shared] dispatch:event message:message reply:^(id result, id error) {
        [self refreshBookmarks];
    }];
}

- (void)addBookmark:(NSString *)url title:(NSString *)title {
    if (![url isKindOfClass:[NSString class]] || ![url length])
        return;
    [_bookmarked addObject:url];
    [self change:@"LegacyFox:Places:AddBookmark"
         message:[NSDictionary dictionaryWithObjectsAndKeys:url, @"url",
                                  [title isKindOfClass:[NSString class]] ? title : @"", @"title", nil]];
}

- (void)removeBookmark:(NSString *)url {
    if (!url)
        return;
    [_bookmarked removeObject:url];
    [self change:@"LegacyFox:Places:RemoveBookmark" message:[NSDictionary dictionaryWithObject:url forKey:@"url"]];
}

- (void)removeHistoryForURL:(NSString *)url {
    if (url)
        [self change:@"LegacyFox:Places:RemoveHistory" message:[NSDictionary dictionaryWithObject:url forKey:@"url"]];
}

- (void)clearHistory {
    [self change:@"LegacyFox:Places:ClearHistory" message:nil];
}

- (void)start {
    // LegacyFox 0.1 kept bookmarks in a property list of its own.
    NSString *old = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LegacyFox/bookmarks.plist"];
    NSArray *plist = [NSArray arrayWithContentsOfFile:old];
    for (NSDictionary *d in [plist reverseObjectEnumerator])
        if ([d isKindOfClass:[NSDictionary class]])
            [self addBookmark:[d objectForKey:@"url"] title:[d objectForKey:@"title"]];
    if (plist)
        [[NSFileManager defaultManager] moveItemAtPath:old toPath:[old stringByAppendingString:@".imported"] error:NULL];
    [self refreshBookmarks];
}

- (void)dealloc {
    [_bookmarked release];
    [_icons release];
    [_lists release];
    [super dealloc];
}

@end
