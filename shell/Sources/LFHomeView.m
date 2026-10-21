#import "LFHomeView.h"
#import <QuartzCore/QuartzCore.h>
#import "LFStore.h"
#import "LFFennec.h"
#import "Gecko/LFGecko.h"
#import <CommonCrypto/CommonDigest.h>

// Before there is any history: a few sites to start from.
static NSArray *LFStarterSites(void) {
    return [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"https://ya.ru/", @"Яндекс", nil],
        [NSArray arrayWithObjects:@"https://www.google.com/", @"Google", nil],
        [NSArray arrayWithObjects:@"https://ru.wikipedia.org/", @"Википедия", nil],
        [NSArray arrayWithObjects:@"https://m.youtube.com/", @"YouTube", nil],
        [NSArray arrayWithObjects:@"https://vk.com/", @"ВКонтакте", nil],
        [NSArray arrayWithObjects:@"https://github.com/", @"GitHub", nil],
        [NSArray arrayWithObjects:@"https://www.reddit.com/", @"Reddit", nil],
        [NSArray arrayWithObjects:@"https://news.ycombinator.com/", @"Hacker News", nil],
        [NSArray arrayWithObjects:@"https://www.mozilla.org/", @"Mozilla", nil], nil];
}

@implementation LFThumbnails

+ (NSString *)pathForURL:(NSString *)url {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/LegacyFox/thumbnails"];
    const char *s = [url UTF8String];
    unsigned char md[CC_MD5_DIGEST_LENGTH];
    CC_MD5(s, (CC_LONG)strlen(s), md);
    NSMutableString *name = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [name appendFormat:@"%02x", md[i]];
    return [[dir stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"jpg"];
}

+ (void)save:(UIImage *)image forURL:(NSString *)url {
    if (!image || ![url hasPrefix:@"http"])
        return;
    NSString *path = [self pathForURL:url];
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    [UIImageJPEGRepresentation(image, 0.7f) writeToFile:path atomically:YES];
}

+ (UIImage *)imageForURL:(NSString *)url {
    if (getenv("LF_DEMO"))
        return nil;
    return url ? [UIImage imageWithContentsOfFile:[self pathForURL:url]] : nil;
}

@end

// A top site: the page's picture on a white card with a shadow, its title
// under it in white, as iOS 6 drew pictures on dark backgrounds.
@interface LFTopSiteItem : UIControl {
    UIView *_card;
    UIImageView *_thumb;
    UILabel *_label;
    NSString *_url;
}
@property(nonatomic, copy) NSString *url;
- (void)setTitle:(NSString *)title image:(UIImage *)image icon:(UIImage *)icon;
@end

// iPad: three pictures across, iPhone: two; Firefox's 136:78 pictures.
static CGSize LFThumbSize(void) { return [LFFennec pad] ? CGSizeMake(196, 112) : CGSizeMake(132, 76); }

@implementation LFTopSiteItem

@synthesize url = _url;

- (id)initWithFrame:(CGRect)frame {
    CGSize t = LFThumbSize();
    if ((self = [super initWithFrame:CGRectMake(0, 0, t.width + 8, t.height + 30)])) {
        _card = [[UIView alloc] initWithFrame:CGRectMake(4, 2, t.width, t.height)];
        [_card setBackgroundColor:[UIColor whiteColor]];
        [_card setUserInteractionEnabled:NO];
        CALayer *layer = [_card layer];
        [layer setBorderColor:[[UIColor whiteColor] CGColor]];
        [layer setBorderWidth:3];
        [layer setShadowColor:[[UIColor blackColor] CGColor]];
        [layer setShadowOpacity:0.55f];
        [layer setShadowRadius:3];
        [layer setShadowOffset:CGSizeMake(0, 2)];
        [layer setShadowPath:[[UIBezierPath bezierPathWithRect:[_card bounds]] CGPath]];
        _thumb = [[UIImageView alloc] initWithFrame:CGRectInset([_card bounds], 3, 3)];
        [_thumb setClipsToBounds:YES];
        [_card addSubview:_thumb];
        [self addSubview:_card];
        _label = [[UILabel alloc] initWithFrame:CGRectMake(0, t.height + 8, t.width + 8, 18)];
        [_label setBackgroundColor:[UIColor clearColor]];
        [_label setTextColor:[UIColor whiteColor]];
        [_label setShadowColor:[UIColor colorWithWhite:0 alpha:0.6f]];
        [_label setShadowOffset:CGSizeMake(0, -1)];
        [_label setFont:[UIFont boldSystemFontOfSize:[LFFennec pad] ? 13 : 12]];
        [_label setTextAlignment:UITextAlignmentCenter];
        [_label setLineBreakMode:UILineBreakModeTailTruncation];
        [self addSubview:_label];
    }
    return self;
}

- (void)setTitle:(NSString *)title image:(UIImage *)image icon:(UIImage *)icon {
    [_label setText:title];
    if (image) {
        [_thumb setContentMode:UIViewContentModeScaleAspectFill];
        [_thumb setImage:image];
    } else {
        // No picture yet: the site's icon in the middle of the card.
        [_thumb setContentMode:UIViewContentModeCenter];
        [_thumb setImage:icon ? icon : [LFFennec image:@"favicon"]];
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [_card setAlpha:highlighted ? 0.6f : 1];
}

- (void)dealloc {
    [_card release];
    [_thumb release];
    [_label release];
    [_url release];
    [super dealloc];
}

@end

@implementation LFHomeView

@synthesize homeDelegate = _homeDelegate;

static NSUInteger LFColumns(void) { return [LFFennec pad] ? 3 : 2; }
static NSUInteger LFTopSitesCount(void) { return [LFFennec pad] ? 9 : 6; }

static UILabel *LFWhiteLabel(CGFloat size, BOOL bold) {
    UILabel *l = [[[UILabel alloc] init] autorelease];
    [l setBackgroundColor:[UIColor clearColor]];
    [l setTextColor:[UIColor whiteColor]];
    [l setShadowColor:[UIColor colorWithWhite:0 alpha:0.6f]];
    [l setShadowOffset:CGSizeMake(0, -1)];
    [l setFont:bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size]];
    return l;
}

// Firefox Home's glossy grey buttons.
static UIButton *LFHomeButton(NSString *size, NSString *title) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *normal = [LFFennec home:[NSString stringWithFormat:@"button_%@_default", size]];
    UIImage *pressed = [LFFennec home:[NSString stringWithFormat:@"button_%@_pressed", size]];
    CGFloat cap = floorf([normal size].width / 2);
    [b setBackgroundImage:[normal stretchableImageWithLeftCapWidth:cap topCapHeight:0] forState:UIControlStateNormal];
    [b setBackgroundImage:[pressed stretchableImageWithLeftCapWidth:cap topCapHeight:0] forState:UIControlStateHighlighted];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.5f] forState:UIControlStateNormal];
    [[b titleLabel] setShadowOffset:CGSizeMake(0, -1)];
    [[b titleLabel] setFont:[UIFont boldSystemFontOfSize:15]];
    return b;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Firefox Home's blue, staying put while the page scrolls.
        [self setBackgroundColor:[UIColor colorWithRed:35 / 255.0 green:65 / 255.0 blue:113 / 255.0 alpha:1]];
        [self setAlwaysBounceVertical:YES];
        [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        _backdrop = [[UIImageView alloc] initWithImage:[LFFennec home:@"Background"]];
        [_backdrop setContentMode:UIViewContentModeScaleToFill];
        [self addSubview:_backdrop];

        _icon = [[UIImageView alloc] initWithImage:[LFFennec image:@"brand_logo"]];
        [_icon setContentMode:UIViewContentModeScaleAspectFit];
        [self addSubview:_icon];
        _logo = [LFWhiteLabel([LFFennec pad] ? 28 : 22, YES) retain];
        [_logo setText:@"LegacyFox"];
        [self addSubview:_logo];
        _heading = [LFWhiteLabel(17, YES) retain];
        [_heading setText:@"Топ сайтов"];
        [self addSubview:_heading];

        _items = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < LFTopSitesCount(); i++) {
            LFTopSiteItem *item = [[LFTopSiteItem alloc] initWithFrame:CGRectZero];
            [item addTarget:self action:@selector(chose:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:item];
            [_items addObject:item];
            [item release];
        }

        _browse = [LFHomeButton(@"medium", @"Все сайты") retain];
        [_browse addTarget:self action:@selector(browseAll) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_browse];

        // The Sync promotion of Firefox for Android, as Firefox Home asked.
        _promoText = [LFWhiteLabel(15, NO) retain];
        [_promoText setNumberOfLines:0];
        [_promoText setTextAlignment:UITextAlignmentCenter];
        [_promoText setText:@"Войдите в аккаунт Mozilla, чтобы получить закладки, журнал и пароли с других устройств."];
        [_promoText setHidden:YES];
        [self addSubview:_promoText];
        _promo = [LFHomeButton(@"large", @"Войти") retain];
        [_promo addTarget:self action:@selector(signIn) forControlEvents:UIControlEventTouchUpInside];
        [_promo setHidden:YES];
        [self addSubview:_promo];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = [self bounds];
    [_backdrop setFrame:b];
    [self sendSubviewToBack:_backdrop];
    BOOL pad = [LFFennec pad];
    CGFloat w = b.size.width;
    NSUInteger cols = LFColumns();
    CGSize item = [(UIView *)[_items objectAtIndex:0] bounds].size;
    CGFloat gap = floorf((w - cols * item.width) / (cols + 1));
    CGFloat iconH = pad ? 56 : 40;
    [_icon setFrame:CGRectMake(gap, pad ? 24 : 14, iconH, iconH)];
    [_logo setFrame:CGRectMake(gap + iconH + 10, CGRectGetMinY([_icon frame]), w - gap * 2 - iconH - 10, iconH)];
    CGFloat y = CGRectGetMaxY([_icon frame]) + (pad ? 22 : 14);
    [_heading setFrame:CGRectMake(gap + 4, y, w - 2 * gap, 22)];
    y += 22 + 10;
    for (NSUInteger i = 0; i < [_items count]; i++) {
        UIView *v = [_items objectAtIndex:i];
        NSUInteger col = i % cols, row = i / cols;
        [v setFrame:CGRectMake(gap + col * (item.width + gap), y + row * (item.height + 12), item.width, item.height)];
    }
    NSUInteger rows = ([_items count] + cols - 1) / cols;
    y += rows * (item.height + 12) + 6;
    [_browse setFrame:CGRectMake(floorf((w - 150) / 2), y, 150, 42)];
    y += 42 + 24;
    if (_promoShown) {
        CGFloat pw = MIN(w - 40, 420);
        CGSize text = [[_promoText text] sizeWithFont:[_promoText font] constrainedToSize:CGSizeMake(pw, 200)];
        [_promoText setFrame:CGRectMake(floorf((w - pw) / 2), y, pw, ceilf(text.height))];
        y += ceilf(text.height) + 12;
        CGFloat bw = MIN(pw, 270);
        [_promo setFrame:CGRectMake(floorf((w - bw) / 2), y, bw, 62)];
        y += 62 + 24;
    }
    [_promoText setHidden:!_promoShown];
    [self setContentSize:CGSizeMake(w, MAX(y, b.size.height + 1))];
}

- (void)showSites:(NSArray *)sites {
    NSMutableArray *list = [NSMutableArray arrayWithArray:sites];
    // Fill up with the starters the user has not got yet.
    for (NSArray *starter in LFStarterSites()) {
        if ([list count] >= [_items count])
            break;
        BOOL have = NO;
        for (LFSite *s in list)
            if ([[s url] isEqualToString:[starter objectAtIndex:0]])
                have = YES;
        if (!have) {
            LFSite *s = [[[LFSite alloc] init] autorelease];
            [s setUrl:[starter objectAtIndex:0]];
            [s setTitle:[starter objectAtIndex:1]];
            [list addObject:s];
        }
    }
    for (NSUInteger i = 0; i < [_items count]; i++) {
        LFTopSiteItem *item = [_items objectAtIndex:i];
        LFSite *site = i < [list count] ? [list objectAtIndex:i] : nil;
        [item setHidden:!site];
        [item setUrl:[site url]];
        [item setTitle:[site displayTitle] image:[LFThumbnails imageForURL:[site url]]
                  icon:[[LFStore shared] iconForURL:[site url]]];
    }
}

- (void)reload {
    [[LFStore shared] topSites:[_items count] done:^(NSArray *sites) {
        [self showSites:sites];
        NSMutableArray *urls = [NSMutableArray array];
        for (LFSite *site in sites)
            [urls addObject:[site url]];
        [[LFStore shared] loadIcons:urls done:^{
            [self showSites:sites];
        }];
    }];
    [self checkAccount];
}

// The promotion only once the account is known to be missing.
- (void)checkAccount {
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:State" message:nil reply:^(id state, id error) {
        if (![state isKindOfClass:[NSDictionary class]])
            return;
        if (![[state objectForKey:@"ready"] boolValue]) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkAccount) object:nil];
            [self performSelector:@selector(checkAccount) withObject:nil afterDelay:1];
            return;
        }
        BOOL missing = [[state objectForKey:@"status"] isEqual:@"not_configured"];
        if (missing != _promoShown) {
            _promoShown = missing;
            [_promo setHidden:!missing];
            [self setNeedsLayout];
        }
    }];
}

- (void)chose:(LFTopSiteItem *)item {
    if ([item url])
        [_homeDelegate homeView:self didChooseURL:[item url]];
}

- (void)browseAll {
    [_homeDelegate homeViewShowAllTopSites:self];
}

- (void)signIn {
    [_homeDelegate homeViewSignIn:self];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_backdrop release];
    [_promoText release];
    [_icon release];
    [_logo release];
    [_heading release];
    [_items release];
    [_browse release];
    [_promo release];
    [super dealloc];
}

@end
