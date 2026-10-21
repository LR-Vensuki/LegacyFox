// The new-tab page, Firefox's about:home of 2012 in the manner of iOS 6:
// Top Sites as page pictures on Firefox Home's blue, a button for all of
// them, and the Sync promotion while no Mozilla account is signed in.
// Drawn natively: an empty tab costs no Gecko page.

@class LFHomeView;

@protocol LFHomeViewDelegate <NSObject>
- (void)homeView:(LFHomeView *)home didChooseURL:(NSString *)url;
- (void)homeViewShowAllTopSites:(LFHomeView *)home;
- (void)homeViewSignIn:(LFHomeView *)home;
@end

// Pictures of pages by address, for Top Sites (Library/Caches).
@interface LFThumbnails : NSObject
+ (void)save:(UIImage *)image forURL:(NSString *)url;
+ (UIImage *)imageForURL:(NSString *)url;
@end

@interface LFHomeView : UIScrollView {
    UIImageView *_backdrop;
    UILabel *_promoText;
    UIImageView *_icon;
    UILabel *_logo;
    UILabel *_heading;
    NSMutableArray *_items;
    UIButton *_browse;
    UIButton *_promo;
    BOOL _promoShown;
    id<LFHomeViewDelegate> _homeDelegate;
}
@property(nonatomic, assign) id<LFHomeViewDelegate> homeDelegate;
- (void)reload;
@end
