#import "Gecko/LFGecko.h"
#import "LFTopBar.h"
#import "LFTabsList.h"
#import "LFAwesomeController.h"
#import "LFHomeView.h"
#import "LFPrompter.h"
#import "LFFindBar.h"

@class LFTab;

@interface LFBrowserViewController : UIViewController <LFGeckoSessionDelegate, LFTopBarDelegate,
                                                       LFTabsListDelegate, UIActionSheetDelegate,
                                                       LFAwesomeControllerDelegate, LFHomeViewDelegate,
                                                       LFFindBarDelegate, UIPopoverControllerDelegate> {
    LFTopBar *_topBar;
    UIView *_pageView;
    UILabel *_placeholder;
    LFTabsList *_tabsList;
    LFAwesomeController *_awesome;
    // iPad: the one popover showing (tabs, the Awesome Screen, share).
    UIPopoverController *_popover;
    LFHomeView *_homeView;
    LFPrompter *_prompter;
    LFFindBar *_findBar;
    NSDictionary *_contextInfo;
    NSMutableArray *_tabs;
    NSMutableArray *_recent;
    LFTab *_current;
    // The tab whose page was closed for memory (memoryCritical), shown as a
    // note until it is opened again; not retained.
    LFTab *_closedForMemory;
}
@end
