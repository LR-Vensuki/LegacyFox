#import "LFSettings.h"
#import "LFStore.h"
#import "Gecko/LFGecko.h"
#import "LFPasswords.h"
#import "LFAccount.h"

static NSString *const kSearchKey = @"LFSearchEngine";

// Names and result addresses (%@ is the escaped query). Yandex first, as in
// the Russian Firefox of 2012.
static NSArray *LFEngines(void) {
    return [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"Яндекс", @"https://ya.ru/search/?text=%@", nil],
        [NSArray arrayWithObjects:@"Google", @"https://www.google.com/search?q=%@", nil],
        [NSArray arrayWithObjects:@"DuckDuckGo", @"https://duckduckgo.com/?q=%@", nil],
        [NSArray arrayWithObjects:@"Bing", @"https://www.bing.com/search?q=%@", nil],
        [NSArray arrayWithObjects:@"Википедия", @"https://ru.wikipedia.org/w/index.php?search=%@", nil],
        nil];
}

@implementation LFSettings

+ (NSArray *)searchEngineNames {
    NSMutableArray *names = [NSMutableArray array];
    for (NSArray *e in LFEngines())
        [names addObject:[e objectAtIndex:0]];
    return names;
}

+ (NSUInteger)searchEngine {
    if (getenv("LF_DEMO"))
        return 0;
    NSInteger i = [[NSUserDefaults standardUserDefaults] integerForKey:kSearchKey];
    return i >= 0 && (NSUInteger)i < [LFEngines() count] ? i : 0;
}

+ (void)setSearchEngine:(NSUInteger)index {
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:kSearchKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)searchEngineName {
    return [[LFEngines() objectAtIndex:[self searchEngine]] objectAtIndex:0];
}

+ (NSString *)searchURLFor:(NSString *)text {
    NSString *escaped = (NSString *)CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)text, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
    NSString *url = [NSString stringWithFormat:[[LFEngines() objectAtIndex:[self searchEngine]] objectAtIndex:1],
                                               escaped];
    [escaped release];
    return url;
}

@end

enum { kSectionAccount, kSectionSearch, kSectionPrivacy, kSectionAbout, kSectionCount };

@implementation LFSettingsController

@synthesize openURL = _openURL;

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [self setTitle:@"Параметры"];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self action:@selector(done)];
        [[self navigationItem] setRightBarButtonItem:done];
        [done release];
    }
    return self;
}

- (void)done {
    [self dismissModalViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return kSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    switch (section) {
    case kSectionAccount: return 1;
    case kSectionSearch: return [LFEngines() count];
    case kSectionPrivacy: return 3;
    default: return 1;
    }
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    switch (section) {
    case kSectionAccount: return @"Основные";
    case kSectionSearch: return @"Поиск";
    case kSectionPrivacy: return @"Приватность и защита";
    default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if (section == kSectionAbout) {
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        return [NSString stringWithFormat:@"LegacyFox %@ на движке Gecko из Firefox 153 ESR.\n"
                                           "Неофициальная сборка, не связана с Mozilla.", version];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                    reuseIdentifier:nil] autorelease];
    switch ([path section]) {
    case kSectionAccount:
        [[cell textLabel] setText:@"Синхронизация"];
        [[cell detailTextLabel] setText:@"Аккаунт Mozilla: закладки, журнал и пароли"];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        break;
    case kSectionSearch:
        [[cell textLabel] setText:[[LFSettings searchEngineNames] objectAtIndex:[path row]]];
        if ((NSUInteger)[path row] == [LFSettings searchEngine])
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        break;
    case kSectionPrivacy:
        if ([path row] == 0) {
            [[cell textLabel] setText:@"Сохранённые пароли"];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            break;
        }
        [[cell textLabel] setText:[path row] == 1 ? @"Удалить журнал посещений" : @"Удалить куки и данные сайтов"];
        [[cell textLabel] setTextAlignment:UITextAlignmentCenter];
        break;
    case kSectionAbout:
        [[cell textLabel] setText:@"О LegacyFox"];
        [[cell detailTextLabel] setText:@"Исходный код движка (MPL 2.0)"];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        break;
    }
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    switch ([path section]) {
    case kSectionAccount: {
        LFAccountController *account = [[LFAccountController alloc] init];
        [account setOpenURL:_openURL];
        [[self navigationController] pushViewController:account animated:YES];
        [account release];
        break;
    }
    case kSectionSearch:
        [LFSettings setSearchEngine:[path row]];
        [table reloadSections:[NSIndexSet indexSetWithIndex:kSectionSearch]
             withRowAnimation:UITableViewRowAnimationNone];
        break;
    case kSectionPrivacy: {
        if ([path row] == 0) {
            LFPasswordsController *passwords = [[LFPasswordsController alloc] init];
            [[self navigationController] pushViewController:passwords animated:YES];
            [passwords release];
            break;
        }
        UIActionSheet *sheet = [[UIActionSheet alloc]
                   initWithTitle:[path row] == 1 ? @"Вся история посещений будет удалена."
                                                 : @"Вы выйдете из аккаунтов на всех сайтах."
                        delegate:self cancelButtonTitle:@"Отмена"
          destructiveButtonTitle:@"Очистить" otherButtonTitles:nil];
        [sheet setTag:[path row] - 1];
        [sheet showInView:[self view]];
        [sheet release];
        break;
    }
    case kSectionAbout:
        if (_openURL)
            _openURL(@"https://hg.mozilla.org/releases/mozilla-esr153/");
        [self done];
        break;
    }
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index != [sheet destructiveButtonIndex])
        return;
    if ([sheet tag] == 0)
        [[LFStore shared] clearHistory];
    else
        [[LFGeckoRuntime shared] dispatch:@"GeckoView:ClearData"
                                  message:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:LFClearSiteData]
                                                                      forKey:@"flags"]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

- (void)dealloc {
    [_openURL release];
    [super dealloc];
}

@end
