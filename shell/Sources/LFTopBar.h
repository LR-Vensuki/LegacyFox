// The browser bars, as a Firefox for iOS 6 would have had them: Firefox
// Home's blue (Mozilla's iOS app of 2010-2012) and iOS's own bar buttons.
// iPad: one toolbar on top, back, forward, share, bookmarks, the address
// field and tabs, as Safari laid out its iPad toolbar. iPhone: the address
// field on top and a black toolbar below, as Firefox Home and Safari had.

@class LFTopBar;

@protocol LFTopBarDelegate <NSObject>
- (void)topBarBack:(LFTopBar *)bar;
- (void)topBarForward:(LFTopBar *)bar;
- (void)topBarReload:(LFTopBar *)bar;
- (void)topBarStop:(LFTopBar *)bar;
- (void)topBar:(LFTopBar *)bar action:(UIBarButtonItem *)item;
- (void)topBar:(LFTopBar *)bar bookmarks:(UIBarButtonItem *)item;
- (void)topBar:(LFTopBar *)bar tabs:(UIBarButtonItem *)item;
// The address field: typing starts, changes, ends, goes.
- (void)topBarDidBeginEditing:(LFTopBar *)bar;
- (void)topBarDidEndEditing:(LFTopBar *)bar;
- (void)topBar:(LFTopBar *)bar textChanged:(NSString *)text;
- (void)topBar:(LFTopBar *)bar submit:(NSString *)text;
@optional
// A long press on the address field.
- (void)topBarLongPress:(LFTopBar *)bar;
@end

@interface LFTopBar : UIView <UITextFieldDelegate> {
    id<LFTopBarDelegate> _delegate;
    UIImageView *_background;
    UIToolbar *_toolbar;      // on the blue: iPad's buttons and field, iPhone's field
    UIToolbar *_bottom;       // iPhone: the buttons, under the page
    UIView *_fieldBox;
    UITextField *_field;
    UIView *_progress;
    UIImageView *_siteIcon;
    UIButton *_reload;
    UIBarButtonItem *_cancelItem;
    UIBarButtonItem *_backItem;
    UIBarButtonItem *_forwardItem;
    UIBarButtonItem *_actionItem;
    UIBarButtonItem *_bookmarksItem;
    UIBarButtonItem *_tabsItem;
    UIBarButtonItem *_fieldItem;
    NSString *_title;
    NSString *_url;
    UIImage *_favicon;
    float _progressValue;
    NSUInteger _tabCount;
    BOOL _loading;
    BOOL _secure;
    BOOL _private;
}
@property(nonatomic, assign) id<LFTopBarDelegate> delegate;
// The iPhone's toolbar under the page (nil on the iPad).
@property(nonatomic, readonly) UIToolbar *bottomBar;
// The address field, for hanging the Awesome Screen from.
@property(nonatomic, readonly) UIView *fieldView;
@property(nonatomic, readonly) UIBarButtonItem *tabsItem;
+ (CGFloat)height;
+ (CGFloat)bottomHeight;
- (void)setTitle:(NSString *)title url:(NSString *)url;
- (void)setLoading:(BOOL)loading;
// 0-1, drawn in the field as Safari did on iOS 6.
- (void)setProgress:(float)progress;
// The site's icon, or nil.
- (void)setFavicon:(UIImage *)icon;
- (void)setSecure:(BOOL)secure;
- (void)setCanGoBack:(BOOL)back canGoForward:(BOOL)forward;
- (void)setTabCount:(NSUInteger)count animated:(BOOL)animated;
// Private tabs: the bar turns Firefox's private purple.
- (void)setPrivate:(BOOL)isPrivate;
- (BOOL)isEditing;
// Starts typing over text (the address, selected).
- (void)beginEditingWithText:(NSString *)text;
- (void)endEditing;
@end
