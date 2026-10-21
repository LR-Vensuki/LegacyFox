#import "LFDownloads.h"
#import "Gecko/LFGecko.h"
#import <QuartzCore/QuartzCore.h>

static NSString *LFBytes(double bytes) {
    if (bytes < 1024)
        return [NSString stringWithFormat:@"%.0f Б", bytes];
    if (bytes < 1024 * 1024)
        return [NSString stringWithFormat:@"%.0f КБ", bytes / 1024];
    return [NSString stringWithFormat:@"%.1f МБ", bytes / (1024 * 1024)];
}

@implementation LFDownloadsController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        [self setTitle:@"Загрузки"];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self action:@selector(close)];
        [[self navigationItem] setRightBarButtonItem:done];
        [done release];
        [[self tableView] setRowHeight:58];
    }
    return self;
}

- (void)close {
    [self dismissModalViewControllerAnimated:YES];
}

- (void)load {
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Downloads:List" message:nil reply:^(id result, id error) {
        [_downloads release];
        _downloads = [[result isKindOfClass:[NSArray class]] ? result : [NSArray array] retain];
        [[self tableView] reloadData];
        BOOL running = NO;
        for (NSDictionary *d in _downloads)
            running |= ![[d objectForKey:@"stopped"] boolValue];
        if (running)
            [self performSelector:@selector(load) withObject:nil afterDelay:1];
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

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [_downloads count];
}

- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return [_downloads count] ? nil : @"Скачанные файлы появятся здесь и в папке Media/Downloads.";
}

- (NSString *)statusOf:(NSDictionary *)d {
    if ([[d objectForKey:@"succeeded"] boolValue])
        return [NSString stringWithFormat:@"%@ · готово", LFBytes([[d objectForKey:@"currentBytes"] doubleValue])];
    if ([[d objectForKey:@"canceled"] boolValue])
        return @"Отменено";
    if ([[d objectForKey:@"error"] isKindOfClass:[NSString class]])
        return @"Ошибка. Нажмите, чтобы повторить";
    double total = [[d objectForKey:@"totalBytes"] doubleValue];
    double current = [[d objectForKey:@"currentBytes"] doubleValue];
    if (total > 0)
        return [NSString stringWithFormat:@"%@ из %@", LFBytes(current), LFBytes(total)];
    return [NSString stringWithFormat:@"%@…", LFBytes(current)];
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"d"];
    if (!cell)
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"d"] autorelease];
    NSDictionary *d = [_downloads objectAtIndex:[path row]];
    [[cell textLabel] setText:[d objectForKey:@"name"]];
    [[cell detailTextLabel] setText:[self statusOf:d]];
    BOOL running = ![[d objectForKey:@"stopped"] boolValue];
    if (running) {
        UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [spin startAnimating];
        [cell setAccessoryView:spin];
        [spin release];
    } else {
        [cell setAccessoryView:nil];
    }
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    NSDictionary *d = [_downloads objectAtIndex:[path row]];
    NSString *dlId = [d objectForKey:@"id"];
    if ([[d objectForKey:@"succeeded"] boolValue]) {
        [_opener release];
        _opener = [[UIDocumentInteractionController interactionControllerWithURL:
                       [NSURL fileURLWithPath:[d objectForKey:@"path"]]] retain];
        [_opener setDelegate:self];
        CGRect r = [table rectForRowAtIndexPath:path];
        if (![_opener presentOpenInMenuFromRect:r inView:table animated:YES]) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Нет подходящего приложения"
                                                        message:[d objectForKey:@"path"] delegate:nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            [a release];
        }
    } else if ([[d objectForKey:@"stopped"] boolValue]) {
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Downloads:Retry"
                                  message:[NSDictionary dictionaryWithObject:dlId forKey:@"id"]
                                    reply:^(id r, id e) { [self load]; }];
    } else {
        [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Downloads:Cancel"
                                  message:[NSDictionary dictionaryWithObject:dlId forKey:@"id"]
                                    reply:^(id r, id e) { [self load]; }];
    }
}

- (NSString *)tableView:(UITableView *)table titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)path {
    return @"Удалить";
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *d = [_downloads objectAtIndex:[path row]];
    [[LFGeckoRuntime shared] dispatch:@"LegacyFox:Downloads:Remove"
                              message:[NSDictionary dictionaryWithObjectsAndKeys:[d objectForKey:@"id"], @"id",
                                          [NSNumber numberWithBool:YES], @"deleteFile", nil]
                                reply:^(id r, id e) { [self load]; }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_opener setDelegate:nil];
    [_opener release];
    [_downloads release];
    [super dealloc];
}

@end

@implementation LFNote

+ (void)show:(NSString *)text inView:(UIView *)view {
    // A dark rounded box low on the screen, gone after a moment, as iOS 6
    // apps showed what had just happened.
    CGRect b = [view bounds];
    UIFont *font = [UIFont boldSystemFontOfSize:15];
    CGFloat w = MIN(b.size.width - 40, MAX(160, [text sizeWithFont:font].width + 40));
    LFNote *note = [[LFNote alloc] initWithFrame:CGRectMake(floorf((b.size.width - w) / 2),
                                                            floorf(b.size.height * 0.72f), w, 46)];
    [note setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
    [note setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.75]];
    [[note layer] setCornerRadius:10];
    [note setUserInteractionEnabled:NO];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset([note bounds], 14, 4)];
    [label setText:text];
    [label setTextColor:[UIColor whiteColor]];
    [label setShadowColor:[UIColor blackColor]];
    [label setShadowOffset:CGSizeMake(0, -1)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:font];
    [label setTextAlignment:UITextAlignmentCenter];
    [label setAdjustsFontSizeToFitWidth:YES];
    [note addSubview:label];
    [label release];
    [note setAlpha:0];
    [view addSubview:note];
    [UIView animateWithDuration:0.25 animations:^{ [note setAlpha:1]; } completion:^(BOOL f) {
        [UIView animateWithDuration:0.4 delay:1.8 options:0 animations:^{ [note setAlpha:0]; }
                         completion:^(BOOL g) { [note removeFromSuperview]; }];
    }];
    [note release];
}

@end
