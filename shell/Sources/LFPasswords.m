#import "LFPasswords.h"
#import "Gecko/LFGecko.h"

@implementation LFPasswordsController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [self setTitle:@"Пароли"];
        [[self navigationItem] setRightBarButtonItem:[self editButtonItem]];
    }
    return self;
}

- (void)load {
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Logins:Get" message:nil reply:^(id result, id error) {
        NSArray *logins = [result isKindOfClass:[NSArray class]] ? result : [NSArray array];
        [_logins release];
        _logins = [[logins sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [[a objectForKey:@"origin"] compare:[b objectForKey:@"origin"]];
        }] retain];
        [[self tableView] reloadData];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self load];
}

static NSString *LFHost(NSDictionary *login) {
    NSString *origin = [login objectForKey:@"origin"];
    NSString *host = [origin isKindOfClass:[NSString class]] ? [[NSURL URLWithString:origin] host] : nil;
    return host ? host : @"?";
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [_logins count];
}

- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return [_logins count] ? nil : @"Когда вы входите на сайт, LegacyFox предложит запомнить пароль.";
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"login"];
    if (!cell)
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"login"] autorelease];
    NSDictionary *login = [_logins objectAtIndex:[path row]];
    [[cell textLabel] setText:LFHost(login)];
    NSString *user = [login objectForKey:@"username"];
    [[cell detailTextLabel] setText:[user isKindOfClass:[NSString class]] && [user length] ? user : @"(без имени)"];
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    [_selected release];
    _selected = [[_logins objectAtIndex:[path row]] retain];
    NSString *user = [_selected objectForKey:@"username"];
    UIActionSheet *sheet = [[UIActionSheet alloc]
        initWithTitle:[NSString stringWithFormat:@"%@\n%@\nПароль: %@", LFHost(_selected),
                          [user length] ? user : @"(без имени)", [_selected objectForKey:@"password"]]
             delegate:self cancelButtonTitle:@"Закрыть" destructiveButtonTitle:nil
    otherButtonTitles:@"Скопировать пароль", @"Скопировать имя", nil];
    [sheet showInView:[self view]];
    [sheet release];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == [sheet firstOtherButtonIndex])
        [[UIPasteboard generalPasteboard] setString:[_selected objectForKey:@"password"]];
    else if (index == [sheet firstOtherButtonIndex] + 1)
        [[UIPasteboard generalPasteboard] setString:[_selected objectForKey:@"username"]];
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *login = [_logins objectAtIndex:[path row]];
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Logins:Remove"
                              message:[NSDictionary dictionaryWithObject:[login objectForKey:@"guid"] forKey:@"guid"]
                                reply:^(id result, id error) { [self load]; }];
}

- (NSString *)tableView:(UITableView *)table titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)path {
    return @"Удалить";
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

- (void)dealloc {
    [_logins release];
    [_selected release];
    [super dealloc];
}

@end
