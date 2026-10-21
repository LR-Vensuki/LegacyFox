// User settings (NSUserDefaults) and the Settings screen, a grouped table
// in the iOS 6 manner under Firefox Home's blue bar.

@interface LFSettings : NSObject
+ (NSArray *)searchEngineNames;
+ (NSUInteger)searchEngine;
+ (void)setSearchEngine:(NSUInteger)index;
+ (NSString *)searchEngineName;
// The search results address for text in the chosen engine.
+ (NSString *)searchURLFor:(NSString *)text;
@end

@interface LFSettingsController : UITableViewController <UIActionSheetDelegate> {
    void (^_openURL)(NSString *);
}
// Opens a page in the browser (the settings screen closes first).
@property(nonatomic, copy) void (^openURL)(NSString *url);
@end
