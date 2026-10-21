// Native dialogs for GeckoView:Prompt: alert(), confirm(), prompt(), HTTP
// authentication, <select> lists, date and time inputs, resubmitting a form
// and leaving a page. One dialog at a time; later prompts wait their turn.

@interface LFPrompter : NSObject <UIAlertViewDelegate> {
    UIViewController *_host;
    NSMutableArray *_queue;      // pending { prompt, reply }
    NSDictionary *_prompt;       // the one on screen
    void (^_reply)(NSDictionary *);
    UIAlertView *_alert;
    UIViewController *_sheet;
}
- (id)initWithHostController:(UIViewController *)host;
- (void)showPrompt:(NSDictionary *)prompt reply:(void (^)(NSDictionary *result))reply;
- (void)dismissPrompt:(NSString *)promptId;
// Developer aid (LF_UI_STEPS "promptok"): presses the dialog's main button.
- (void)confirmForTesting;
@end
