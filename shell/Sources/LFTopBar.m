#import "LFTopBar.h"
#import "LFFennec.h"
#import <QuartzCore/QuartzCore.h>

// Firefox Home's navigation bar blue (header.png at its middle), for the
// tint of the bar buttons on it; Firefox 20's purple for private tabs.
static UIColor *LFBlue(void) { return [UIColor colorWithRed:35 / 255.0 green:65 / 255.0 blue:113 / 255.0 alpha:1]; }
static UIColor *LFPurple(void) { return [UIColor colorWithRed:0.33 green:0.18 blue:0.45 alpha:1]; }

@implementation LFTopBar

@synthesize delegate = _delegate;
@synthesize bottomBar = _bottom;
@synthesize fieldView = _fieldBox;
@synthesize tabsItem = _tabsItem;

+ (CGFloat)height { return 44; }
+ (CGFloat)bottomHeight { return [LFFennec pad] ? 0 : 44; }

// header.png, as Firefox Home drew it into its navigation bars; purple
// laid over it in private tabs.
static UIImage *LFHeader(BOOL isPrivate) {
    UIImage *header = [LFFennec home:@"header"];
    if (!isPrivate)
        return [header stretchableImageWithLeftCapWidth:16 topCapHeight:0];
    UIGraphicsBeginImageContextWithOptions([header size], YES, [header scale]);
    CGRect r = CGRectMake(0, 0, [header size].width, [header size].height);
    [header drawInRect:r];
    [LFPurple() setFill];
    UIRectFillUsingBlendMode(r, kCGBlendModeHue);
    UIImage *purple = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [purple stretchableImageWithLeftCapWidth:16 topCapHeight:0];
}

// A bar on the blue: its own background stays clear (iOS 5 and later),
// iOS 4 tints it instead.
static void LFClearToolbar(UIToolbar *bar) {
    if ([bar respondsToSelector:@selector(setBackgroundImage:forToolbarPosition:barMetrics:)]) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 1);
        UIImage *clear = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [bar setBackgroundImage:clear forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    }
}

- (UIBarButtonItem *)item:(UIImage *)image action:(SEL)action {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain
                                                            target:self action:action];
    return [item autorelease];
}

- (UIBarButtonItem *)space:(CGFloat)width {
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:
                                  width ? UIBarButtonSystemItemFixedSpace : UIBarButtonSystemItemFlexibleSpace
                                                                           target:nil action:NULL];
    [space setWidth:width];
    return [space autorelease];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        BOOL pad = [LFFennec pad];
        _background = [[UIImageView alloc] initWithImage:LFHeader(NO)];
        [_background setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [_background setFrame:[self bounds]];
        [self addSubview:_background];

        _toolbar = [[UIToolbar alloc] initWithFrame:[self bounds]];
        [_toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_toolbar setTintColor:LFBlue()];
        LFClearToolbar(_toolbar);
        [self addSubview:_toolbar];

        // The field: iOS's rounded one, the site's icon in front, reload or
        // stop at the end, page loading filling it with blue.
        _fieldBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 31)];
        _field = [[UITextField alloc] initWithFrame:[_fieldBox bounds]];
        [_field setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [_field setBorderStyle:UITextBorderStyleRoundedRect];
        [_field setFont:[UIFont systemFontOfSize:15]];
        [_field setTextColor:[UIColor colorWithWhite:0.15 alpha:1]];
        [_field setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_field setPlaceholder:@"Введите поиск или адрес"];
        // The ordinary keyboard: searches need its space bar (the web
        // search keyboard came only with iOS 7).
        [_field setKeyboardType:UIKeyboardTypeDefault];
        [_field setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_field setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_field setReturnKeyType:UIReturnKeyGo];
        [_field setClearButtonMode:UITextFieldViewModeWhileEditing];
        [_field setDelegate:self];
        [_field addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
        _siteIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 26, 16)];
        [_siteIcon setContentMode:UIViewContentModeCenter];
        [_field setLeftView:_siteIcon];
        [_field setLeftViewMode:UITextFieldViewModeUnlessEditing];
        _reload = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_reload setFrame:CGRectMake(0, 0, 28, 28)];
        [[_reload imageView] setContentMode:UIViewContentModeScaleAspectFit];
        [_reload setContentEdgeInsets:UIEdgeInsetsMake(6, 6, 6, 6)];
        [_reload setShowsTouchWhenHighlighted:YES];
        [_reload addTarget:self action:@selector(reloadOrStop) forControlEvents:UIControlEventTouchUpInside];
        [_field setRightView:_reload];
        [_field setRightViewMode:UITextFieldViewModeUnlessEditing];
        [_fieldBox addSubview:_field];
        _progress = [[UIView alloc] init];
        [_progress setUserInteractionEnabled:NO];
        [_progress setClipsToBounds:YES];
        [[_progress layer] setCornerRadius:4];
        CAGradientLayer *blue = [CAGradientLayer layer];
        [blue setColors:[NSArray arrayWithObjects:
            (id)[[UIColor colorWithRed:0.62 green:0.80 blue:0.98 alpha:1] CGColor],
            (id)[[UIColor colorWithRed:0.38 green:0.63 blue:0.95 alpha:1] CGColor], nil]];
        [blue setFrame:CGRectMake(0, 0, 2000, 40)];
        [[_progress layer] addSublayer:blue];
        [self placeProgress];
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(pressed:)];
        [_fieldBox addGestureRecognizer:press];
        [press release];
        _fieldItem = [[UIBarButtonItem alloc] initWithCustomView:_fieldBox];

        _backItem = [[self item:[LFFennec home:@"backward"] action:@selector(back)] retain];
        _forwardItem = [[self item:[LFFennec home:@"forward"] action:@selector(forward)] retain];
        _actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                    target:self action:@selector(action:)];
        _bookmarksItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                                                                       target:self action:@selector(bookmarks:)];
        _tabsItem = [[self item:nil action:@selector(tabs:)] retain];
        _cancelItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStyleBordered
                                                      target:self action:@selector(cancel)];

        if (pad) {
            [_toolbar setItems:[NSArray arrayWithObjects:_backItem, [self space:6], _forwardItem, [self space:6],
                                   _actionItem, [self space:6], _bookmarksItem, [self space:10], _fieldItem,
                                   [self space:10], _tabsItem, nil]];
        } else {
            // Firefox Home's toolbar under the page was black.
            _bottom = [[UIToolbar alloc] init];
            [_bottom setBarStyle:UIBarStyleBlack];
            [_bottom setItems:[NSArray arrayWithObjects:_backItem, [self space:0], _forwardItem, [self space:0],
                                  _actionItem, [self space:0], _bookmarksItem, [self space:0], _tabsItem, nil]];
            [_toolbar setItems:[NSArray arrayWithObject:_fieldItem]];
        }
        _tabCount = 0;
        [self setTabCount:1 animated:NO];
        [self setCanGoBack:NO canGoForward:NO];
        [self updateIcons];
    }
    return self;
}

// The blue goes over the field's white and under its text.
- (void)placeProgress {
    UIView *below = nil;
    for (UIView *v in [_field subviews])
        if ([NSStringFromClass([v class]) rangeOfString:@"Background"].location != NSNotFound)
            below = v;
    if (below)
        [_field insertSubview:_progress aboveSubview:below];
    else
        [_field insertSubview:_progress atIndex:0];
}

- (void)layoutSubviews {
    CGRect b = [self bounds];
    [_background setFrame:b];
    [_toolbar setFrame:b];
    CGFloat w = b.size.width;
    CGFloat fieldW;
    if ([LFFennec pad])
        fieldW = w - 270;   // five buttons and their spaces
    else
        fieldW = w - 12 - ([_field isEditing] ? 78 : 0);
    [_fieldBox setFrame:CGRectMake(0, 0, MAX(100, fieldW), 31)];
    // The toolbar lays its items out again when one changes size.
    [_toolbar setItems:[_toolbar items] animated:NO];
    [self updateProgressFrame];
}

- (void)updateProgressFrame {
    CGRect f = CGRectInset([_field bounds], 2, 2);
    BOOL show = _loading && ![_field isEditing] && _progressValue > 0;
    f.size.width = floorf(f.size.width * MIN(1, MAX(0.05f, _progressValue)));
    [_progress setFrame:f];
    [_progress setHidden:!show];
}

// ---- state ----

- (void)showText {
    if ([_field isEditing])
        return;
    // Firefox shows the page's title; the address while typing.
    [_field setText:[_title length] ? _title : _url];
}

- (void)setTitle:(NSString *)title url:(NSString *)url {
    if ([url isEqualToString:@"about:home"])
        url = nil;
    [_title release];
    _title = [title copy];
    if (![url isEqualToString:_url]) {
        [_url release];
        _url = [url copy];
        _secure = [url hasPrefix:@"https://"];
        [self updateIcons];
    }
    [self showText];
}

- (void)updateIcons {
    UIImage *icon = _favicon;
    if (!icon && [_url length])
        icon = [LFFennec image:@"favicon"];
    if (_secure && !_favicon)
        icon = [LFFennec image:@"site_security_verified"];
    [_siteIcon setImage:icon];
    [_siteIcon setContentMode:[icon size].width > 16 ? UIViewContentModeScaleAspectFit : UIViewContentModeCenter];
    [_siteIcon setBounds:CGRectMake(0, 0, 26, 16)];
    [_reload setImage:[LFFennec image:_loading ? @"urlbar_stop" : @"ic_menu_reload"] forState:UIControlStateNormal];
    [_reload setHidden:![_url length]];
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    if (!loading)
        _progressValue = 0;
    [self updateIcons];
    [self updateProgressFrame];
}

- (void)setProgress:(float)progress {
    _progressValue = progress;
    [self updateProgressFrame];
}

- (void)setFavicon:(UIImage *)icon {
    [_favicon release];
    _favicon = [icon retain];
    [self updateIcons];
}

- (void)setSecure:(BOOL)secure {
    _secure = secure;
    [self updateIcons];
}

- (void)setCanGoBack:(BOOL)back canGoForward:(BOOL)forward {
    [_backItem setEnabled:back];
    [_forwardItem setEnabled:forward];
}

// Firefox Home's tab icon with the number of tabs cut out of it.
- (UIImage *)tabsIcon:(NSUInteger)count {
    UIImage *tab = [LFFennec home:@"Tabs"];
    CGSize size = [tab size];
    UIGraphicsBeginImageContextWithOptions(size, NO, [tab scale]);
    [tab drawAtPoint:CGPointZero];
    NSString *text = count > 99 ? @"∞" : [NSString stringWithFormat:@"%lu", (unsigned long)count];
    UIFont *font = [UIFont boldSystemFontOfSize:count > 9 ? 10 : 12];
    CGSize t = [text sizeWithFont:font];
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeDestinationOut);
    // The tab's body: x 1.5-22 and y 6.5-23 of the 30-point icon.
    [text drawAtPoint:CGPointMake(floorf(12 - t.width / 2), floorf(15 - t.height / 2)) withFont:font];
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return icon;
}

- (void)setTabCount:(NSUInteger)count animated:(BOOL)animated {
    if (count == _tabCount)
        return;
    _tabCount = count;
    [_tabsItem setImage:[self tabsIcon:count]];
}

- (void)setPrivate:(BOOL)isPrivate {
    if (isPrivate == _private)
        return;
    _private = isPrivate;
    [_background setImage:LFHeader(isPrivate)];
    [_toolbar setTintColor:isPrivate ? LFPurple() : LFBlue()];
}

// ---- the field ----

- (BOOL)isEditing { return [_field isEditing]; }

- (void)beginEditingWithText:(NSString *)text {
    [_field becomeFirstResponder];
    [_field setText:text];
    [_field selectAll:nil];
}

- (void)endEditing {
    [_field resignFirstResponder];
}

- (void)textFieldDidBeginEditing:(UITextField *)field {
    [field setText:_url];
    [field selectAll:nil];
    [self updateProgressFrame];
    if (![LFFennec pad]) {
        [_toolbar setItems:[NSArray arrayWithObjects:_fieldItem, _cancelItem, nil] animated:YES];
        [UIView animateWithDuration:0.25 animations:^{ [self layoutSubviews]; }];
    }
    [_delegate topBarDidBeginEditing:self];
}

- (void)textFieldDidEndEditing:(UITextField *)field {
    [self showText];
    [self updateProgressFrame];
    if (![LFFennec pad]) {
        [_toolbar setItems:[NSArray arrayWithObject:_fieldItem] animated:YES];
        [UIView animateWithDuration:0.25 animations:^{ [self layoutSubviews]; }];
    }
    [_delegate topBarDidEndEditing:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
    NSString *text = [[[field text] copy] autorelease];
    if (![[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length])
        return NO;
    [field resignFirstResponder];
    [_delegate topBar:self submit:text];
    return NO;
}

- (void)textChanged {
    [_delegate topBar:self textChanged:[_field text]];
}

- (void)cancel {
    [_field resignFirstResponder];
}

- (void)pressed:(UILongPressGestureRecognizer *)press {
    if ([press state] == UIGestureRecognizerStateBegan && ![_field isEditing] &&
        [_delegate respondsToSelector:@selector(topBarLongPress:)])
        [_delegate topBarLongPress:self];
}

// ---- buttons ----

- (void)back { [_delegate topBarBack:self]; }
- (void)forward { [_delegate topBarForward:self]; }
- (void)action:(UIBarButtonItem *)item { [_delegate topBar:self action:item]; }
- (void)bookmarks:(UIBarButtonItem *)item { [_delegate topBar:self bookmarks:item]; }
- (void)tabs:(UIBarButtonItem *)item { [_delegate topBar:self tabs:item]; }

- (void)reloadOrStop {
    if (_loading)
        [_delegate topBarStop:self];
    else
        [_delegate topBarReload:self];
}

- (void)dealloc {
    [_field setDelegate:nil];
    [_background release];
    [_toolbar release];
    [_bottom release];
    [_fieldBox release];
    [_field release];
    [_progress release];
    [_siteIcon release];
    [_reload release];
    [_cancelItem release];
    [_backItem release];
    [_forwardItem release];
    [_actionItem release];
    [_bookmarksItem release];
    [_tabsItem release];
    [_fieldItem release];
    [_title release];
    [_url release];
    [_favicon release];
    [super dealloc];
}

@end
