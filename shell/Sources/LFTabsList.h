// The open tabs, as an iOS 6 list: each with a picture of its page, title
// and address; a tap switches, a swipe or Edit closes, + opens a new one.
// A popover from the tabs button on the iPad, a screen of its own on the
// iPhone.

@class LFTabsList;

@protocol LFTabsListDelegate <NSObject>
- (NSUInteger)numberOfTabsInList:(LFTabsList *)list;
- (NSString *)tabsList:(LFTabsList *)list titleAtIndex:(NSUInteger)index;
- (NSString *)tabsList:(LFTabsList *)list urlAtIndex:(NSUInteger)index;
// A small picture of the page, or nil.
- (UIImage *)tabsList:(LFTabsList *)list thumbnailAtIndex:(NSUInteger)index;
- (BOOL)tabsList:(LFTabsList *)list isPrivateAtIndex:(NSUInteger)index;
- (NSUInteger)selectedIndexInTabsList:(LFTabsList *)list;
- (void)tabsList:(LFTabsList *)list didSelectIndex:(NSUInteger)index;
- (void)tabsList:(LFTabsList *)list didCloseIndex:(NSUInteger)index;
- (void)tabsListDidAddTab:(LFTabsList *)list;
- (void)tabsListDidFinish:(LFTabsList *)list;
@end

@interface LFTabsList : UITableViewController {
    id<LFTabsListDelegate> _delegate;
}
@property(nonatomic, assign) id<LFTabsListDelegate> delegate;
- (void)reload;
@end
