// Downloads (LegacyFoxDownloads.sys.mjs in the engine): files go to
// /var/mobile/Media/Downloads; this screen follows them and opens finished
// ones in another app ("Open in...").

@interface LFDownloadsController : UITableViewController <UIDocumentInteractionControllerDelegate> {
    NSArray *_downloads;
    UIDocumentInteractionController *_opener;
}
@end

// A short note at the bottom of the browser: "Загрузка: file.zip".
@interface LFNote : UIView {
    UILabel *_label;
}
+ (void)show:(NSString *)text inView:(UIView *)view;
@end
