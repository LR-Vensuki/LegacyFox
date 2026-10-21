#import "Gecko/LFGecko.h"

// One browser tab: its Gecko session and what the bars show for it.
@interface LFTab : NSObject {
    LFGeckoSession *_session;
    NSString *_url;
    NSString *_title;
    BOOL _canGoBack;
    BOOL _canGoForward;
    BOOL _loading;
    float _progress;
    NSDictionary *_savedState;
    BOOL _privateTab;
    UIImage *_thumbnail;
}
// A small picture of the page for the tabs panel (kept while unloaded).
@property(nonatomic, retain) UIImage *thumbnail;
@property(nonatomic) BOOL privateTab;
// What survives a restart: { url, title, state }.
- (NSDictionary *)archive;
- (id)initWithArchive:(NSDictionary *)archive;
@property(nonatomic, readonly) LFGeckoSession *session;
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL canGoBack;
@property(nonatomic) BOOL canGoForward;
@property(nonatomic) BOOL loading;
@property(nonatomic) float progress;
// What a tab list shows: the title, or the address before there is one.
- (NSString *)displayTitle;
// Without a session the tab keeps only its address and title (no page in
// memory) until it is loaded again, the way Firefox for Android did it.
- (BOOL)isLoaded;
- (void)unload;
// A tab for a window a page opened (target=_blank): Gecko loads it.
- (id)initWithOpenedSessionId:(NSString *)windowId delegate:(id<LFGeckoSessionDelegate>)delegate;
// Starts a session (delegate set) and loads the tab's address; a tab with
// no address yet stays without one (the home page).
- (void)loadWithDelegate:(id<LFGeckoSessionDelegate>)delegate;
@end
