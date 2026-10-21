// Firefox's Awesome Screen as an iOS 6 list: Top Sites, Bookmarks and
// History behind a segmented control, and while an address or search is
// typed, the matches with a web search on top. On the iPad it hangs from
// the address field (or the bookmarks button) in a popover, on the iPhone
// it covers the page under the address bar.

@class LFAwesomeController;

// url with percent escapes decoded, for display.
NSString *LFDisplayURL(NSString *url);

@protocol LFAwesomeControllerDelegate <NSObject>
- (void)awesomeController:(LFAwesomeController *)awesome didChooseURL:(NSString *)url;
- (void)awesomeController:(LFAwesomeController *)awesome didSearch:(NSString *)text;
@end

@interface LFAwesomeController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    UIToolbar *_bar;
    UISegmentedControl *_sections;
    UITableView *_table;
    NSInteger _section;  // 0 top sites, 1 bookmarks, 2 history
    NSString *_query;
    NSArray *_rows;
    NSArray *_groups;  // history: { title, rows } by day
    id<LFAwesomeControllerDelegate> _delegate;
}
@property(nonatomic, assign) id<LFAwesomeControllerDelegate> delegate;
// nil or empty: the three lists; otherwise the matches for the text.
- (void)setQuery:(NSString *)query;
// 0 Top Sites, 1 Bookmarks, 2 History.
- (void)showSection:(NSInteger)section;
@end
