// Mozilla account and Firefox Sync (LegacyFoxSync.sys.mjs in the engine):
// signing in happens on accounts.firefox.com in a tab, the way desktop
// Firefox does it; this screen shows the account and the last sync.

@interface LFAccountController : UITableViewController <UIActionSheetDelegate> {
    NSDictionary *_state;   // { status, email, displayName, syncing, lastSync }
    void (^_openURL)(NSString *);
}
@property(nonatomic, copy) void (^openURL)(NSString *url);
@end
