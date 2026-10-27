#import "LFSettings.h"
#import "LFStore.h"
#import "Gecko/LFGecko.h"
#import "LFPasswords.h"
#import "LFAccount.h"

static NSString *const kSearchKey = @"LFSearchEngine";

// Names and result addresses (%@ is the escaped query); Google is the
// default (see +searchEngine).
static NSArray *LFEngines(void) {
    return [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"Яндекс", @"https://ya.ru/search/?text=%@", nil],
        [NSArray arrayWithObjects:@"Google", @"https://www.google.com/search?q=%@", nil],
        [NSArray arrayWithObjects:@"DuckDuckGo", @"https://duckduckgo.com/?q=%@", nil],
        [NSArray arrayWithObjects:@"Bing", @"https://www.bing.com/search?q=%@", nil],
        [NSArray arrayWithObjects:@"Википедия", @"https://ru.wikipedia.org/w/index.php?search=%@", nil],
        nil];
}

NSString *const LFUserAgentChanged = @"LFUserAgentChanged";

@implementation LFSettings

+ (NSArray *)searchEngineNames {
    NSMutableArray *names = [NSMutableArray array];
    for (NSArray *e in LFEngines())
        [names addObject:[e objectAtIndex:0]];
    return names;
}

+ (NSUInteger)searchEngine {
    // Google unless the user chose another.
    id chosen = getenv("LF_DEMO") ? nil : [[NSUserDefaults standardUserDefaults] objectForKey:kSearchKey];
    if (!chosen)
        return 1;
    NSInteger i = [chosen integerValue];
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

// ---- User-Agent ----

static NSString *const kAgentKey = @"LFUserAgent";
static NSString *const kCustomAgentKey = @"LFCustomUserAgent";

// The Gecko inside (rv:153): sites see the Firefox they are dealing with.
static NSString *const kGeckoVersion = @"153.0";

+ (NSArray *)userAgentNames {
    return [NSArray arrayWithObjects:@"Firefox для Android", @"Firefox для компьютера", @"Safari на iOS 6",
                                     @"Стандартный (Gecko для iOS)", @"Свой…", nil];
}

+ (NSUInteger)userAgent {
    // Firefox for Android by default: the same engine, and the mobile pages
    // sites make for it (Google turns old iOS versions away).
    NSInteger i = [[NSUserDefaults standardUserDefaults] integerForKey:kAgentKey];
    return i >= 0 && (NSUInteger)i < [[self userAgentNames] count] ? i : 0;
}

+ (void)setUserAgent:(NSUInteger)index {
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:kAgentKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)customUserAgent {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kCustomAgentKey];
}

+ (void)setCustomUserAgent:(NSString *)agent {
    [[NSUserDefaults standardUserDefaults] setObject:agent forKey:kCustomAgentKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)userAgentString {
    BOOL pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    switch ([self userAgent]) {
    case 0:
        return [NSString stringWithFormat:@"Mozilla/5.0 (Android 14; %@; rv:%@) Gecko/%@ Firefox/%@",
                                          pad ? @"Tablet" : @"Mobile", kGeckoVersion, kGeckoVersion, kGeckoVersion];
    case 1:
        return [NSString stringWithFormat:@"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:%@) Gecko/20100101 Firefox/%@",
                                          kGeckoVersion, kGeckoVersion];
    case 2:
        return pad ? @"Mozilla/5.0 (iPad; CPU OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) "
                      "Version/6.0 Mobile/10B329 Safari/8536.25"
                   : @"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) "
                      "Version/6.0 Mobile/10B329 Safari/8536.25";
    case 4: {
        NSString *custom = [self customUserAgent];
        return [custom length] ? custom : nil;
    }
    default:
        return nil;
    }
}

// ---- downloads ----

static NSString *const kFolderKey = @"LFDownloadFolder";
static NSString *const kCustomFolderKey = @"LFCustomDownloadFolder";

+ (NSArray *)downloadFolderPaths {
    return [NSArray arrayWithObjects:@"/var/mobile/Media/Downloads", @"/var/mobile/Documents",
                                     @"/var/mobile/Media/DCIM/LegacyFox", nil];
}

+ (NSArray *)downloadFolderNames {
    return [NSArray arrayWithObjects:@"Загрузки (Media/Downloads)", @"Документы (/var/mobile/Documents)",
                                     @"Фотоплёнка (Media/DCIM/LegacyFox)", @"Своя папка…", nil];
}

+ (NSUInteger)downloadFolder {
    NSInteger i = [[NSUserDefaults standardUserDefaults] integerForKey:kFolderKey];
    return i >= 0 && (NSUInteger)i < [[self downloadFolderNames] count] ? i : 0;
}

+ (void)setDownloadFolder:(NSUInteger)index {
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:kFolderKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self applyDownloadFolder];
}

+ (NSString *)customDownloadPath {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kCustomFolderKey];
}

+ (void)setCustomDownloadPath:(NSString *)path {
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:kCustomFolderKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)downloadPath {
    NSUInteger i = [self downloadFolder];
    NSArray *paths = [self downloadFolderPaths];
    if (i < [paths count])
        return [paths objectAtIndex:i];
    NSString *custom = [[self customDownloadPath] stringByStandardizingPath];
    return [custom hasPrefix:@"/"] ? custom : [paths objectAtIndex:0];
}

// ---- GPU ----

static NSString *const kGPUKey = @"LFGPURendering";

+ (BOOL)gpuRendering {
    NSNumber *on = [[NSUserDefaults standardUserDefaults] objectForKey:kGPUKey];
    return on ? [on boolValue] : YES;
}

+ (void)setGpuRendering:(BOOL)on {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:kGPUKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)applyGpuRendering {
    // LF_SWGL_GPU in the debug file wins, for test runs.
    if (!getenv("LF_SWGL_GPU"))
        setenv("LF_SWGL_GPU", [self gpuRendering] ? "1" : "0", 1);
}

+ (void)applyDownloadFolder {
    NSString *path = [self downloadPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    // A default pref, as prefs/legacyfox.js sets it: nothing in the profile.
    [[LFGeckoRuntime shared] dispatch:@"GeckoView:SetDefaultPrefs"
                              message:[NSDictionary dictionaryWithObject:path forKey:@"browser.download.dir"]];
}

@end

@implementation LFChoiceList

- (id)initWithTitle:(NSString *)title names:(NSArray *)names selected:(NSUInteger)selected
              chose:(void (^)(NSUInteger))chose {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [self setTitle:title];
        _names = [names copy];
        _selected = selected;
        _chose = [chose copy];
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [_names count];
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier:nil] autorelease];
    [[cell textLabel] setText:[_names objectAtIndex:[path row]]];
    [[cell textLabel] setAdjustsFontSizeToFitWidth:YES];
    if ((NSUInteger)[path row] == _selected)
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    _selected = [path row];
    [table reloadData];
    if (_chose)
        _chose(_selected);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {
    return YES;
}

- (void)dealloc {
    [_names release];
    [_chose release];
    [super dealloc];
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
    case kSectionAccount: return 4;
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
    if (section == kSectionAccount)
        return @"Графический процессор помогает рисовать страницы: прокрутка плавнее, "
                "но бесконечные ленты закрываются раньше. Действует после перезапуска LegacyFox.";
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
        if ([path row] == 0) {
            [[cell textLabel] setText:@"Синхронизация"];
            [[cell detailTextLabel] setText:@"Аккаунт Mozilla: закладки, журнал и пароли"];
        } else if ([path row] == 3) {
            [[cell textLabel] setText:@"Рисовать на GPU"];
            UISwitch *on = [[[UISwitch alloc] init] autorelease];
            [on setOn:[LFSettings gpuRendering]];
            [on addTarget:self action:@selector(gpuChanged:) forControlEvents:UIControlEventValueChanged];
            [cell setAccessoryView:on];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            break;
        } else if ([path row] == 1) {
            [[cell textLabel] setText:@"Представляться сайтам как"];
            [[cell detailTextLabel] setText:[[LFSettings userAgentNames] objectAtIndex:[LFSettings userAgent]]];
        } else {
            [[cell textLabel] setText:@"Папка для загрузок"];
            [[cell detailTextLabel] setText:[LFSettings downloadPath]];
        }
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
        if ([path row] == 3)
            break;
        if ([path row] == 1) {
            [self chooseUserAgent];
            break;
        }
        if ([path row] == 2) {
            [self chooseDownloadFolder];
            break;
        }
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

- (void)gpuChanged:(UISwitch *)on {
    [LFSettings setGpuRendering:[on isOn]];
}

// ---- choices ----

- (void)chooseUserAgent {
    LFSettingsController *me = self;
    LFChoiceList *list = [[LFChoiceList alloc] initWithTitle:@"Представляться как" names:[LFSettings userAgentNames]
                                                    selected:[LFSettings userAgent]
                                                       chose:^(NSUInteger i) {
        if (i == [[LFSettings userAgentNames] count] - 1) {
            [me askText:@"Свой User-Agent" value:[LFSettings customUserAgent] tag:1];
            return;
        }
        [LFSettings setUserAgent:i];
        [[NSNotificationCenter defaultCenter] postNotificationName:LFUserAgentChanged object:nil];
        [[me tableView] reloadData];
    }];
    [[self navigationController] pushViewController:list animated:YES];
    [list release];
}

- (void)chooseDownloadFolder {
    LFSettingsController *me = self;
    LFChoiceList *list = [[LFChoiceList alloc] initWithTitle:@"Папка для загрузок" names:[LFSettings downloadFolderNames]
                                                    selected:[LFSettings downloadFolder]
                                                       chose:^(NSUInteger i) {
        if (i == [[LFSettings downloadFolderNames] count] - 1) {
            [me askText:@"Папка для загрузок" value:[LFSettings customDownloadPath] ?: @"/var/mobile/" tag:2];
            return;
        }
        [LFSettings setDownloadFolder:i];
        [[me tableView] reloadData];
    }];
    [[self navigationController] pushViewController:list animated:YES];
    [list release];
}

- (void)askText:(NSString *)title value:(NSString *)value tag:(NSInteger)tag {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:self
                                          cancelButtonTitle:@"Отмена" otherButtonTitles:@"Готово", nil];
    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    UITextField *field = [alert textFieldAtIndex:0];
    [field setText:value];
    [field setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [field setAutocorrectionType:UITextAutocorrectionTypeNo];
    [alert setTag:tag];
    [alert show];
    [alert release];
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if (index == [alert cancelButtonIndex])
        return;
    NSString *text = [[[alert textFieldAtIndex:0] text]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![text length])
        return;
    if ([alert tag] == 1) {
        [LFSettings setCustomUserAgent:text];
        [LFSettings setUserAgent:[[LFSettings userAgentNames] count] - 1];
        [[NSNotificationCenter defaultCenter] postNotificationName:LFUserAgentChanged object:nil];
    } else {
        if (![text hasPrefix:@"/"])
            text = [@"/var/mobile/" stringByAppendingPathComponent:text];
        [LFSettings setCustomDownloadPath:text];
        [LFSettings setDownloadFolder:[[LFSettings downloadFolderNames] count] - 1];
    }
    [[self navigationController] popToViewController:self animated:YES];
    [[self tableView] reloadData];
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
