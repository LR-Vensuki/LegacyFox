#import "LFAwesomeController.h"
#import "LFStore.h"
#import "LFFennec.h"
#import "LFSettings.h"

// Addresses as people read them: %D0%92... shown as letters.
NSString *LFDisplayURL(NSString *url) {
    NSString *decoded = [url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return decoded ? decoded : url;
}

@implementation LFAwesomeController

@synthesize delegate = _delegate;

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil]))
        [self setContentSizeForViewInPopover:CGSizeMake(420, 520)];
    return self;
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 420, 520)];
    [view setBackgroundColor:[UIColor whiteColor]];

    _bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 420, 44)];
    [_bar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [_bar setTintColor:[UIColor colorWithRed:35 / 255.0 green:65 / 255.0 blue:113 / 255.0 alpha:1]];
    _sections = [[UISegmentedControl alloc] initWithItems:
        [NSArray arrayWithObjects:@"Топ сайтов", @"Закладки", @"История", nil]];
    [_sections setSegmentedControlStyle:UISegmentedControlStyleBar];
    [_sections setSelectedSegmentIndex:_section];
    [_sections setFrame:CGRectMake(0, 0, 300, 30)];
    [_sections addTarget:self action:@selector(sectionChanged) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                          target:nil action:NULL];
    UIBarButtonItem *segments = [[UIBarButtonItem alloc] initWithCustomView:_sections];
    [_bar setItems:[NSArray arrayWithObjects:flex, segments, flex, nil]];
    [segments release];
    [flex release];
    [view addSubview:_bar];

    _table = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, 420, 476) style:UITableViewStylePlain];
    [_table setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_table setDataSource:self];
    [_table setDelegate:self];
    [_table setRowHeight:52];
    [view addSubview:_table];
    [self setView:view];
    [view release];
    [self reload];
}

- (void)viewWillLayoutSubviews {
    [self layout];
}

- (void)layout {
    CGRect b = [[self view] bounds];
    BOOL searching = [_query length] > 0;
    [_bar setHidden:searching];
    CGFloat top = searching ? 0 : 44;
    [_bar setFrame:CGRectMake(0, 0, b.size.width, 44)];
    [_table setFrame:CGRectMake(0, top, b.size.width, b.size.height - top)];
}

- (void)setQuery:(NSString *)query {
    [_query release];
    _query = [[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] copy];
    if (![self isViewLoaded])
        return;
    [self reload];
    [self layout];
}

- (void)showSection:(NSInteger)section {
    _section = section;
    [_sections setSelectedSegmentIndex:section];
    if ([self isViewLoaded])
        [self reload];
}

- (void)sectionChanged {
    _section = [_sections selectedSegmentIndex];
    [self reload];
}

- (BOOL)hasSearchRow { return [_query length] > 0; }

// History by day, as Firefox grouped it.
- (NSArray *)groupsByDay:(NSArray *)rows {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *parts = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                          fromDate:[NSDate date]];
    NSTimeInterval today = [[calendar dateFromComponents:parts] timeIntervalSince1970];
    NSTimeInterval starts[] = { today, today - 86400, today - 7 * 86400, 0 };
    NSString *titles[] = { @"Сегодня", @"Вчера", @"7 дней назад", @"Более 7 дней назад" };
    NSMutableArray *groups = [NSMutableArray array];
    NSMutableArray *current = nil;
    int g = -1;
    for (LFSite *site in rows) {
        int k = 0;
        while (k < 3 && [site lastVisit] < starts[k])
            k++;
        if (k != g) {
            g = k;
            current = [NSMutableArray array];
            [groups addObject:[NSArray arrayWithObjects:titles[k], current, nil]];
        }
        [current addObject:site];
    }
    return groups;
}

- (void)reload {
    LFStore *store = [LFStore shared];
    // Answers arrive later; one for an older query or section is dropped.
    NSString *query = [[_query copy] autorelease];
    NSInteger section = _section;
    LFSitesBlock show = ^(NSArray *rows) {
        if ((query != _query && ![query isEqualToString:_query]) || section != _section)
            return;
        [_rows release];
        _rows = [rows retain];
        [_groups release];
        _groups = section == 2 && ![query length] ? [[self groupsByDay:rows] retain] : nil;
        [_table reloadData];
        NSMutableArray *urls = [NSMutableArray array];
        for (LFSite *site in rows)
            [urls addObject:[site url]];
        UITableView *table = _table;
        [store loadIcons:urls done:^{
            [table reloadData];
        }];
    };
    if ([_query length])
        [store matches:_query limit:30 done:show];
    else if (_section == 0)
        [store topSites:30 done:show];
    else if (_section == 1)
        [store bookmarks:500 done:show];
    else
        [store history:300 done:show];
}

- (LFSite *)siteAt:(NSIndexPath *)path {
    if (_groups)
        return [[[_groups objectAtIndex:[path section]] objectAtIndex:1] objectAtIndex:[path row]];
    NSInteger row = [path row] - ([self hasSearchRow] ? 1 : 0);
    return row >= 0 && row < (NSInteger)[_rows count] ? [_rows objectAtIndex:row] : nil;
}

// ---- table ----

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return _groups ? [_groups count] : 1;
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return _groups ? [[_groups objectAtIndex:section] objectAtIndex:0] : nil;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (_groups)
        return [[[_groups objectAtIndex:section] objectAtIndex:1] count];
    return [_rows count] + ([self hasSearchRow] ? 1 : 0);
}

// The site's icon on a 16-point square, Firefox's default one without.
static UIImage *LFRowIcon(UIImage *icon) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
    [icon drawInRect:CGRectMake(2, 2, 16, 16)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"site"];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"site"] autorelease];
        [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:15]];
        [[cell detailTextLabel] setFont:[UIFont systemFontOfSize:13]];
        [[cell detailTextLabel] setTextColor:[UIColor colorWithRed:0.25 green:0.4 blue:0.6 alpha:1]];
    }
    if (!_groups && [self hasSearchRow] && [path row] == 0) {
        [[cell textLabel] setText:[NSString stringWithFormat:@"Искать «%@»", _query]];
        [[cell detailTextLabel] setText:[LFSettings searchEngineName]];
        [[cell imageView] setImage:LFRowIcon([LFFennec image:@"ic_awesomebar_search"])];
        [cell setAccessoryView:nil];
        return cell;
    }
    LFSite *site = [self siteAt:path];
    [[cell textLabel] setText:[site displayTitle]];
    [[cell detailTextLabel] setText:LFDisplayURL([site url])];
    UIImage *icon = [[LFStore shared] iconForURL:[site url]];
    [[cell imageView] setImage:LFRowIcon(icon ? icon : [LFFennec image:@"favicon"])];
    BOOL starred = _section != 1 && [[LFStore shared] isBookmarked:[site url]];
    [cell setAccessoryView:starred ? [[[UIImageView alloc] initWithImage:[LFFennec image:@"ic_awesomebar_star"]] autorelease]
                                   : nil];
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (!_groups && [self hasSearchRow] && [path row] == 0) {
        [_delegate awesomeController:self didSearch:_query];
        return;
    }
    [_delegate awesomeController:self didChooseURL:[[self siteAt:path] url]];
}

// Bookmarks and history entries go away with a swipe.
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return ![_query length] && (_section == 1 || _section == 2);
}

- (NSString *)tableView:(UITableView *)table titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)path {
    return @"Удалить";
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path {
    LFSite *site = [self siteAt:path];
    if (_section == 1)
        [[LFStore shared] removeBookmark:[site url]];
    else
        [[LFStore shared] removeHistoryForURL:[site url]];
    NSMutableArray *rows = [[_rows mutableCopy] autorelease];
    [rows removeObject:site];
    [_rows release];
    _rows = [rows retain];
    if (_groups) {
        [_groups release];
        _groups = [[self groupsByDay:_rows] retain];
        [table reloadData];
    } else {
        [table deleteRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {
    return YES;
}

- (void)dealloc {
    [_table setDelegate:nil];
    [_table setDataSource:nil];
    [_bar release];
    [_sections release];
    [_table release];
    [_query release];
    [_rows release];
    [_groups release];
    [super dealloc];
}

@end
