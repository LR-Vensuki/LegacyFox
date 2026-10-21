// History and bookmarks, kept by Gecko in Places (see LegacyFoxPlaces.sys.mjs
// in the engine): Gecko records visits itself, and Firefox Sync carries both
// between devices. Answers come back asynchronously, on the main thread.

@interface LFSite : NSObject {
    NSString *_url;
    NSString *_title;
    NSUInteger _visits;
    NSTimeInterval _lastVisit;
}
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *title;
@property(nonatomic) NSUInteger visits;
// Seconds since 1970, 0 when never visited.
@property(nonatomic) NSTimeInterval lastVisit;
// The title, or the host when the page has none.
- (NSString *)displayTitle;
@end

typedef void (^LFSitesBlock)(NSArray *sites);

@interface LFStore : NSObject {
    NSMutableSet *_bookmarked;  // addresses of all bookmarks, for menus
    NSMutableDictionary *_icons;  // address -> UIImage or NSNull
    NSMutableDictionary *_lists;  // the last answer of each list query
}
+ (LFStore *)shared;
- (void)topSites:(NSUInteger)limit done:(LFSitesBlock)done;
- (void)history:(NSUInteger)limit done:(LFSitesBlock)done;
- (void)bookmarks:(NSUInteger)limit done:(LFSitesBlock)done;
// History and bookmarks whose address or title has every word of text,
// bookmarks first, then by frecency.
- (void)matches:(NSString *)text limit:(NSUInteger)limit done:(LFSitesBlock)done;
// From the last refresh of the bookmark list (kept current by this class).
- (BOOL)isBookmarked:(NSString *)url;
- (void)addBookmark:(NSString *)url title:(NSString *)title;
- (void)removeBookmark:(NSString *)url;
- (void)removeHistoryForURL:(NSString *)url;
- (void)clearHistory;
// Site icons from Places: what is known already, and a lookup of the rest
// (done runs when any arrive).
- (UIImage *)iconForURL:(NSString *)url;
- (void)loadIcons:(NSArray *)urls done:(void (^)(void))done;
- (void)forgetIconForURL:(NSString *)url;
// After a page loads: its icon from Places, fetched from the site first
// when Places has none.
- (void)fetchIconForPage:(NSString *)url done:(void (^)(UIImage *icon))done;
// Fills the bookmark cache; also moves bookmarks of LegacyFox 0.1 (a
// property list) into Places once.
- (void)start;
@end
