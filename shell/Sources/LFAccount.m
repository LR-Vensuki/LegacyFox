#import "LFAccount.h"
#import "Gecko/LFGecko.h"

@implementation LFAccountController

@synthesize openURL = _openURL;

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped]))
        [self setTitle:@"Аккаунт Mozilla"];
    return self;
}

- (BOOL)signedIn {
    return [[_state objectForKey:@"status"] isEqual:@"signedin"];
}

- (void)load {
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:State" message:nil reply:^(id result, id error) {
        [_state release];
        _state = [[result isKindOfClass:[NSDictionary class]] ? result : nil retain];
        [[self tableView] reloadData];
        // While a sync runs, look again.
        if ([[_state objectForKey:@"syncing"] boolValue])
            [self performSelector:@selector(load) withObject:nil afterDelay:2];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self load];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(load) object:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return [self signedIn] ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (![self signedIn])
        return 1;
    return section == 0 ? 2 : 1;
}

- (NSString *)lastSyncText {
    if ([[_state objectForKey:@"syncing"] boolValue])
        return @"Синхронизация…";
    double ms = [[_state objectForKey:@"lastSync"] doubleValue];
    if (ms <= 0)
        return @"Ещё не было";
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    [f setDateStyle:NSDateFormatterMediumStyle];
    [f setTimeStyle:NSDateFormatterShortStyle];
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:ms / 1000]];
}

- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if (![self signedIn]) {
        NSString *status = [_state objectForKey:@"status"];
        if ([status isEqual:@"not_verified"])
            return @"Подтвердите вход по ссылке из письма, которое прислала Mozilla.";
        if ([status isEqual:@"login_failed"])
            return @"Mozilla просит войти снова.";
        return @"Закладки, история и пароли будут общими с Firefox на компьютере и телефоне.";
    }
    return section == 0 ? @"Синхронизируются закладки, история, пароли и данные форм." : nil;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    BOOL button = ![self signedIn] || [path section] == 1;
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:button ? UITableViewCellStyleDefault
                                                                           : UITableViewCellStyleValue1
                                                    reuseIdentifier:nil] autorelease];
    if (![self signedIn]) {
        [[cell textLabel] setText:@"Войти в аккаунт Mozilla"];
        [[cell textLabel] setTextAlignment:UITextAlignmentCenter];
        [[cell textLabel] setTextColor:[UIColor colorWithRed:0.85 green:0.38 blue:0.05 alpha:1]];
        return cell;
    }
    if ([path section] == 0) {
        if ([path row] == 0) {
            [[cell textLabel] setText:@"Аккаунт"];
            [[cell detailTextLabel] setText:[_state objectForKey:@"email"]];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        } else {
            [[cell textLabel] setText:@"Синхронизировать"];
            [[cell detailTextLabel] setText:[self lastSyncText]];
        }
    } else {
        [[cell textLabel] setText:@"Выйти"];
        [[cell textLabel] setTextAlignment:UITextAlignmentCenter];
        [[cell textLabel] setTextColor:[UIColor colorWithRed:0.75 green:0.15 blue:0.1 alpha:1]];
    }
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (![self signedIn]) {
        void (^open)(NSString *) = [[_openURL retain] autorelease];
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:SignInURL" message:nil reply:^(id url, id error) {
            if ([url isKindOfClass:[NSString class]] && open) {
                [self dismissModalViewControllerAnimated:YES];
                open(url);
            }
        }];
        return;
    }
    if ([path section] == 0 && [path row] == 1) {
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:SyncNow" message:nil reply:^(id r, id e) {
            [self load];
        }];
    } else if ([path section] == 1) {
        UIActionSheet *sheet = [[UIActionSheet alloc]
                   initWithTitle:@"Данные останутся на устройстве, но перестанут синхронизироваться."
                        delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Выйти"
               otherButtonTitles:nil];
        [sheet showInView:[self view]];
        [sheet release];
    }
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index != [sheet destructiveButtonIndex])
        return;
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Sync:SignOut" message:nil reply:^(id r, id e) {
        [self load];
    }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_state release];
    [_openURL release];
    [super dealloc];
}

@end
