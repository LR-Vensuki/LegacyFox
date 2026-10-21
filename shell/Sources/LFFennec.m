#import "LFFennec.h"

@implementation LFFennec

+ (BOOL)pad {
    static int pad = -1;
    // LF_PHONE (debug file): the phone interface on an iPad, for testing.
    if (pad < 0)
        pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && !getenv("LF_PHONE");
    return pad;
}

+ (CGFloat)toolbarHeight {
    // values-xlarge-v11/dimens.xml and values/dimens.xml.
    return [self pad] ? 56 : 48;
}

+ (CGFloat)scale {
    UIScreen *screen = [UIScreen mainScreen];
    return [screen respondsToSelector:@selector(scale)] ? [screen scale] : 1;
}

+ (UIImage *)image:(NSString *)name {
    NSString *file = [@"fx_" stringByAppendingString:name];
    if (![self pad] && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        file = [file stringByAppendingString:@"~iphone"];
    return [UIImage imageNamed:file];
}

+ (UIImage *)home:(NSString *)name {
    return [UIImage imageNamed:[@"fh_" stringByAppendingString:name]];
}

+ (NSDictionary *)ninePatches {
    static NSDictionary *patches;
    if (!patches) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ninepatch" ofType:@"plist"];
        patches = [[NSDictionary alloc] initWithContentsOfFile:path];
    }
    return patches;
}

static UIEdgeInsets LFInsets(NSArray *a) {
    if ([a count] != 4)
        return UIEdgeInsetsZero;
    return UIEdgeInsetsMake([[a objectAtIndex:0] floatValue], [[a objectAtIndex:1] floatValue],
                            [[a objectAtIndex:2] floatValue], [[a objectAtIndex:3] floatValue]);
}

+ (UIEdgeInsets)insets:(NSString *)name key:(NSString *)key {
    NSString *idiom = [self pad] ? @"ipad" : @"iphone";
    return LFInsets([[[self ninePatches] objectForKey:name] objectForKey:[idiom stringByAppendingString:key]]);
}

+ (UIImage *)stretchable:(NSString *)name {
    UIImage *image = [self image:name];
    UIEdgeInsets caps = [self insets:name key:@""];
    if ([image respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
        return [image resizableImageWithCapInsets:caps resizingMode:UIImageResizingModeStretch];
    if ([image respondsToSelector:@selector(resizableImageWithCapInsets:)])
        return [image resizableImageWithCapInsets:caps];
    return [image stretchableImageWithLeftCapWidth:(NSInteger)caps.left topCapHeight:(NSInteger)caps.top];
}

+ (UIEdgeInsets)contentInsets:(NSString *)name {
    return [self insets:name key:@"Content"];
}

+ (UIColor *)tile:(NSString *)name {
    return [UIColor colorWithPatternImage:[self image:name]];
}

+ (UIImage *)highlight {
    static UIImage *highlight;
    if (!highlight) {
        // angle 90: #E66000 at the bottom, #FF9500 at the top.
        CGSize size = CGSizeMake(1, 64);
        UIGraphicsBeginImageContextWithOptions(size, YES, [self scale]);
        CGContextRef c = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = { 1, 0x95 / 255.0, 0, 1,  0xE6 / 255.0, 0x60 / 255.0, 0, 1 };
        CGGradientRef g = CGGradientCreateWithColorComponents(space, colors, NULL, 2);
        CGContextDrawLinearGradient(c, g, CGPointZero, CGPointMake(0, size.height), 0);
        CGGradientRelease(g);
        CGColorSpaceRelease(space);
        highlight = [UIGraphicsGetImageFromCurrentImageContext() retain];
        UIGraphicsEndImageContext();
    }
    return highlight;
}

+ (UIImage *)image:(UIImage *)image tinted:(UIColor *)color {
    if (!image)
        return nil;
    UIGraphicsBeginImageContextWithOptions([image size], NO, [image scale]);
    CGRect r = CGRectMake(0, 0, [image size].width, [image size].height);
    [image drawInRect:r];
    [color setFill];
    UIRectFillUsingBlendMode(r, kCGBlendModeSourceAtop);
    UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tinted;
}

+ (UIColor *)rgb:(unsigned)rgb {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0
                            blue:(rgb & 0xff) / 255.0 alpha:1];
}

+ (UIColor *)argb:(unsigned)argb {
    return [[self rgb:argb & 0xffffff] colorWithAlphaComponent:((argb >> 24) & 0xff) / 255.0];
}

+ (NSArray *)spinnerFrames {
    static NSArray *frames;
    if (!frames) {
        NSMutableArray *list = [NSMutableArray array];
        for (int i = 1; i <= 12; i++) {
            UIImage *frame = [self image:[NSString stringWithFormat:@"progress_spinner_%d", i]];
            if (frame)
                [list addObject:frame];
        }
        frames = [list copy];
    }
    return frames;
}

+ (UIButton *)buttonWithIcon:(UIImage *)icon background:(UIImage *)normal pressed:(UIImage *)pressed {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:icon forState:UIControlStateNormal];
    [button setBackgroundImage:normal forState:UIControlStateNormal];
    [button setBackgroundImage:pressed forState:UIControlStateHighlighted];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    return button;
}

@end

void LFFennecShadow(UILabel *label, unsigned argb) {
    [label setShadowColor:[LFFennec argb:argb]];
    [label setShadowOffset:CGSizeMake(0, 1)];
}
