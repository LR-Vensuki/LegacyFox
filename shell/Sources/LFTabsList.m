#import "LFTabsList.h"
#import "LFFennec.h"
#import "LFAwesomeController.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kRowHeight = 64;

@implementation LFTabsList

@synthesize delegate = _delegate;

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        [self setTitle:@"Вкладки"];
        UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                             target:self action:@selector(add)];
        [[self navigationItem] setRightBarButtonItem:add];
        [add release];
        [[self navigationItem] setLeftBarButtonItem:[self editButtonItem]];
        if (![LFFennec pad]) {
            UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self action:@selector(done)];
            [[self navigationItem] setLeftBarButtonItem:done];
            [done release];
            if ([[self navigationItem] respondsToSelector:@selector(setRightBarButtonItems:)])
                [[self navigationItem] setRightBarButtonItems:[NSArray arrayWithObjects:add, [self editButtonItem], nil]];
        }
        [self setContentSizeForViewInPopover:CGSizeMake(360, 6 * kRowHeight)];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[self tableView] setRowHeight:kRowHeight];
}

- (void)reload {
    [[self tableView] reloadData];
    NSUInteger count = [_delegate numberOfTabsInList:self];
    [self setContentSizeForViewInPopover:CGSizeMake(360, MIN(9, MAX(3, count)) * kRowHeight)];
    NSUInteger i = [_delegate selectedIndexInTabsList:self];
    if (i < count)
        [[self tableView] scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]
                                atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)add {
    [_delegate tabsListDidAddTab:self];
}

- (void)done {
    [_delegate tabsListDidFinish:self];
}

// ---- table ----

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [_delegate numberOfTabsInList:self];
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"tab"];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tab"] autorelease];
        [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:15]];
        [[cell detailTextLabel] setFont:[UIFont systemFontOfSize:13]];
        [[cell detailTextLabel] setTextColor:[UIColor colorWithRed:0.25 green:0.4 blue:0.6 alpha:1]];
        [[cell imageView] setContentMode:UIViewContentModeScaleAspectFill];
        [[cell imageView] setClipsToBounds:YES];
        [[[cell imageView] layer] setBorderColor:[[UIColor colorWithWhite:0.6 alpha:1] CGColor]];
        [[[cell imageView] layer] setBorderWidth:1];
    }
    NSUInteger i = [path row];
    NSString *title = [_delegate tabsList:self titleAtIndex:i];
    if ([_delegate tabsList:self isPrivateAtIndex:i])
        title = [@"Приватная: " stringByAppendingString:title];
    [[cell textLabel] setText:title];
    [[cell detailTextLabel] setText:LFDisplayURL([_delegate tabsList:self urlAtIndex:i])];
    // The picture at the size of a row: 78 x 45 points, Firefox's proportions.
    UIImage *thumb = [_delegate tabsList:self thumbnailAtIndex:i];
    if (!thumb)
        thumb = [LFFennec image:@"tab_thumbnail_default"];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(78, 45), YES, 0);
    [thumb drawInRect:CGRectMake(0, 0, 78, 45)];
    [[cell imageView] setImage:UIGraphicsGetImageFromCurrentImageContext()];
    UIGraphicsEndImageContext();
    [cell setAccessoryType:i == [_delegate selectedIndexInTabsList:self] ? UITableViewCellAccessoryCheckmark
                                                                          : UITableViewCellAccessoryNone];
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    [_delegate tabsList:self didSelectIndex:[path row]];
}

- (NSString *)tableView:(UITableView *)table titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)path {
    return @"Закрыть";
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path {
    NSUInteger before = [_delegate numberOfTabsInList:self];
    [_delegate tabsList:self didCloseIndex:[path row]];
    // The last tab is not closed but starts over.
    if ([_delegate numberOfTabsInList:self] < before)
        [table deleteRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationFade];
    [table reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {
    return YES;
}

@end
