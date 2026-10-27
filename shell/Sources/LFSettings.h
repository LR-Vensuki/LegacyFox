// User settings (NSUserDefaults) and the Settings screen, a grouped table
// in the iOS 6 manner under Firefox Home's blue bar.

// Posted when the User-Agent choice changes.
extern NSString *const LFUserAgentChanged;

@interface LFSettings : NSObject
+ (NSArray *)searchEngineNames;
+ (NSUInteger)searchEngine;
+ (void)setSearchEngine:(NSUInteger)index;
+ (NSString *)searchEngineName;
// The search results address for text in the chosen engine.
+ (NSString *)searchURLFor:(NSString *)text;
// How the browser introduces itself to sites: the choices' names, the one
// chosen, and its User-Agent string (nil: Gecko's own).
+ (NSArray *)userAgentNames;
+ (NSUInteger)userAgent;
+ (void)setUserAgent:(NSUInteger)index;
+ (NSString *)userAgentString;
+ (NSString *)customUserAgent;
+ (void)setCustomUserAgent:(NSString *)agent;
// Where downloads are saved: the choices, the one chosen, its folder.
+ (NSArray *)downloadFolderNames;
+ (NSUInteger)downloadFolder;
+ (void)setDownloadFolder:(NSUInteger)index;
+ (NSString *)customDownloadPath;
+ (void)setCustomDownloadPath:(NSString *)path;
+ (NSString *)downloadPath;
// Hands the download folder to Gecko (at start and after a change).
+ (void)applyDownloadFolder;
// Pages shaded on the GPU (SWGL's GLES2 path): read once at start, before
// Gecko, as LF_SWGL_GPU; a change takes effect at the next start.
+ (BOOL)gpuRendering;
+ (void)setGpuRendering:(BOOL)on;
+ (void)applyGpuRendering;
@end

// A list of choices with a check mark, for the settings.
@interface LFChoiceList : UITableViewController {
    NSArray *_names;
    NSUInteger _selected;
    void (^_chose)(NSUInteger);
}
- (id)initWithTitle:(NSString *)title names:(NSArray *)names selected:(NSUInteger)selected
              chose:(void (^)(NSUInteger index))chose;
@end

@interface LFSettingsController : UITableViewController <UIActionSheetDelegate, UIAlertViewDelegate> {
    void (^_openURL)(NSString *);
}
// Opens a page in the browser (the settings screen closes first).
@property(nonatomic, copy) void (^openURL)(NSString *url);
@end
