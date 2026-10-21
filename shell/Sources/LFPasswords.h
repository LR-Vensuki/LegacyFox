// Saved passwords, read from and removed in Gecko's own login store (see
// LegacyFoxLogins.sys.mjs in the engine). Shown in Settings.

@interface LFPasswordsController : UITableViewController <UIActionSheetDelegate> {
    NSArray *_logins;   // { guid, origin, username, password }
    NSDictionary *_selected;
}
@end
