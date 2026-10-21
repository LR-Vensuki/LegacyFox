// The look of Firefox 17 for Android (2012), from its own images: they are
// in the bundle as fx_<name> (tools/fennec-ui/import.py brings them over
// from Mozilla's sources), one set for the iPad (Firefox's tablet images)
// and one for the iPhone (its phone images).

@interface LFFennec : NSObject
// Firefox's tablet interface (iPad) or its phone one.
+ (BOOL)pad;
// Height of the toolbar and its kin: 56 on tablets, 48 on phones.
+ (CGFloat)toolbarHeight;
+ (UIImage *)image:(NSString *)name;
// Firefox Home's images (fh_<name>), for the iOS bars.
+ (UIImage *)home:(NSString *)name;
// A nine-patch, stretched where Android stretched it.
+ (UIImage *)stretchable:(NSString *)name;
// Where a nine-patch keeps its content.
+ (UIEdgeInsets)contentInsets:(NSString *)name;
// A texture repeated over an area (Android's tileMode="repeat").
+ (UIColor *)tile:(NSString *)name;
// drawable/highlight.xml: the orange of a pressed button.
+ (UIImage *)highlight;
// An image in one color where it is not transparent (Android's
// setColorFilter, used for disabled buttons: 0xFF999999).
+ (UIImage *)image:(UIImage *)image tinted:(UIColor *)color;
+ (UIColor *)rgb:(unsigned)rgb;
+ (UIColor *)argb:(unsigned)argb;
// progress_spinner.xml: the 12 frames shown in place of the site icon
// while a page loads.
+ (NSArray *)spinnerFrames;
// Point-to-pixel scale of the main screen.
+ (CGFloat)scale;
// A button with Android's states: normal and pressed images (either may
// be nil) behind an icon.
+ (UIButton *)buttonWithIcon:(UIImage *)icon background:(UIImage *)normal pressed:(UIImage *)pressed;
@end

// A label with Android's text shadow (shadowRadius 1, dy 1).
void LFFennecShadow(UILabel *label, unsigned argb);
