#import "LFPrompter.h"

// ---- <select>: a list to pick one or several entries from ------------------

@interface LFChoiceController : UITableViewController {
    NSMutableArray *_items;      // flattened: { label, id, disabled, group, selected }
    BOOL _multiple;
    void (^_done)(NSArray *ids);  // nil ids: cancelled
}
- (id)initWithChoices:(NSArray *)choices multiple:(BOOL)multiple done:(void (^)(NSArray *ids))done;
@end

@implementation LFChoiceController

- (void)addChoices:(NSArray *)choices group:(BOOL)inGroup {
    for (NSDictionary *c in choices) {
        if (![c isKindOfClass:[NSDictionary class]] || [[c objectForKey:@"separator"] boolValue])
            continue;
        NSArray *sub = [c objectForKey:@"items"];
        BOOL isGroup = [sub isKindOfClass:[NSArray class]];
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        id label = [c objectForKey:@"label"];
        [item setObject:[label isKindOfClass:[NSString class]] ? label : @"" forKey:@"label"];
        id cid = [c objectForKey:@"id"];
        if (cid)
            [item setObject:cid forKey:@"id"];
        [item setObject:[NSNumber numberWithBool:isGroup || [[c objectForKey:@"disabled"] boolValue]] forKey:@"disabled"];
        [item setObject:[NSNumber numberWithBool:isGroup] forKey:@"header"];
        [item setObject:[NSNumber numberWithBool:inGroup] forKey:@"inGroup"];
        [item setObject:[NSNumber numberWithBool:[[c objectForKey:@"selected"] boolValue]] forKey:@"selected"];
        [_items addObject:item];
        if (isGroup)
            [self addChoices:sub group:YES];
    }
}

- (id)initWithChoices:(NSArray *)choices multiple:(BOOL)multiple done:(void (^)(NSArray *ids))done {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _items = [[NSMutableArray alloc] init];
        _multiple = multiple;
        _done = [done copy];
        [self addChoices:choices group:NO];
        UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self action:@selector(cancel)];
        [[self navigationItem] setLeftBarButtonItem:cancel];
        [cancel release];
        if (multiple) {
            UIBarButtonItem *ok = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self action:@selector(finish)];
            [[self navigationItem] setRightBarButtonItem:ok];
            [ok release];
        }
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Start at the selected entry, as a <select> does.
    for (NSUInteger i = 0; i < [_items count]; i++)
        if ([[[_items objectAtIndex:i] objectForKey:@"selected"] boolValue]) {
            [[self tableView] scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]
                                    atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
            break;
        }
}

- (void)finishWith:(NSArray *)ids {
    void (^done)(NSArray *) = [[_done retain] autorelease];
    [_done release];
    _done = nil;
    [self dismissModalViewControllerAnimated:YES];
    if (done)
        done(ids);
}

- (void)cancel { [self finishWith:nil]; }

- (void)finish {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *item in _items)
        if ([[item objectForKey:@"selected"] boolValue] && [item objectForKey:@"id"])
            [ids addObject:[item objectForKey:@"id"]];
    [self finishWith:ids];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [_items count];
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"c"];
    if (!cell)
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"] autorelease];
    NSDictionary *item = [_items objectAtIndex:[path row]];
    BOOL header = [[item objectForKey:@"header"] boolValue];
    [[cell textLabel] setText:[item objectForKey:@"label"]];
    [[cell textLabel] setFont:header ? [UIFont boldSystemFontOfSize:15] : [UIFont systemFontOfSize:17]];
    [[cell textLabel] setTextColor:[[item objectForKey:@"disabled"] boolValue] ? [UIColor grayColor] : [UIColor blackColor]];
    [cell setIndentationLevel:[[item objectForKey:@"inGroup"] boolValue] ? 1 : 0];
    [cell setAccessoryType:[[item objectForKey:@"selected"] boolValue] ? UITableViewCellAccessoryCheckmark
                                                                       : UITableViewCellAccessoryNone];
    [cell setSelectionStyle:[[item objectForKey:@"disabled"] boolValue] ? UITableViewCellSelectionStyleNone
                                                                        : UITableViewCellSelectionStyleBlue];
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    NSMutableDictionary *item = [_items objectAtIndex:[path row]];
    [table deselectRowAtIndexPath:path animated:YES];
    if ([[item objectForKey:@"disabled"] boolValue] || ![item objectForKey:@"id"])
        return;
    if (!_multiple) {
        [self finishWith:[NSArray arrayWithObject:[item objectForKey:@"id"]]];
        return;
    }
    BOOL on = ![[item objectForKey:@"selected"] boolValue];
    [item setObject:[NSNumber numberWithBool:on] forKey:@"selected"];
    [table reloadRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationNone];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

- (void)dealloc {
    [_items release];
    [_done release];
    [super dealloc];
}

@end

// ---- date and time inputs ------------------------------------------------------

@interface LFDateController : UIViewController {
    UIDatePicker *_picker;
    NSString *_mode;
    NSString *_value;
    void (^_done)(NSString *value);  // nil: cancelled, "": cleared
}
- (id)initWithMode:(NSString *)mode value:(NSString *)value done:(void (^)(NSString *value))done;
@end

@implementation LFDateController

+ (NSString *)formatForMode:(NSString *)mode {
    if ([mode isEqualToString:@"time"])
        return @"HH:mm";
    if ([mode isEqualToString:@"datetime-local"])
        return @"yyyy-MM-dd'T'HH:mm";
    if ([mode isEqualToString:@"month"])
        return @"yyyy-MM";
    return @"yyyy-MM-dd";
}

- (NSDateFormatter *)formatter {
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    NSLocale *posix = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
    [f setLocale:posix];
    [f setDateFormat:[LFDateController formatForMode:_mode]];
    return f;
}

- (id)initWithMode:(NSString *)mode value:(NSString *)value done:(void (^)(NSString *value))done {
    if ((self = [super init])) {
        _mode = [mode copy];
        _value = [value copy];
        _done = [done copy];
        UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self action:@selector(cancel)];
        UIBarButtonItem *ok = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                            target:self action:@selector(finish)];
        [[self navigationItem] setLeftBarButtonItem:cancel];
        [[self navigationItem] setRightBarButtonItem:ok];
        [cancel release];
        [ok release];
        [self setTitle:@"Выбор даты"];
    }
    return self;
}

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
    [root setBackgroundColor:[UIColor colorWithWhite:0.85 alpha:1]];
    _picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 0, 320, 216)];
    [_picker setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    if ([_mode isEqualToString:@"time"])
        [_picker setDatePickerMode:UIDatePickerModeTime];
    else if ([_mode isEqualToString:@"datetime-local"])
        [_picker setDatePickerMode:UIDatePickerModeDateAndTime];
    else
        [_picker setDatePickerMode:UIDatePickerModeDate];
    NSDate *date = [_value length] ? [[self formatter] dateFromString:_value] : nil;
    [_picker setDate:date ? date : [NSDate date]];
    [root addSubview:_picker];
    UIButton *clear = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [clear setTitle:@"Очистить" forState:UIControlStateNormal];
    [clear setFrame:CGRectMake(20, 232, 280, 44)];
    [clear setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [clear addTarget:self action:@selector(clear) forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:clear];
    [self setView:root];
    [root release];
    [self setContentSizeForViewInPopover:CGSizeMake(320, 300)];
}

- (void)finishWith:(NSString *)value {
    void (^done)(NSString *) = [[_done retain] autorelease];
    [_done release];
    _done = nil;
    [self dismissModalViewControllerAnimated:YES];
    if (done)
        done(value);
}

- (void)cancel { [self finishWith:nil]; }
- (void)clear { [self finishWith:@""]; }
- (void)finish { [self finishWith:[[self formatter] stringFromDate:[_picker date]]]; }

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

- (void)dealloc {
    [_picker release];
    [_mode release];
    [_value release];
    [_done release];
    [super dealloc];
}

@end

// ---- the prompter ------------------------------------------------------------------

@implementation LFPrompter

- (id)initWithHostController:(UIViewController *)host {
    if ((self = [super init])) {
        _host = host;
        _queue = [[NSMutableArray alloc] init];
    }
    return self;
}

static NSString *LFString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (void)showPrompt:(NSDictionary *)prompt reply:(void (^)(NSDictionary *))reply {
    [_queue addObject:[NSArray arrayWithObjects:prompt, [[reply copy] autorelease], nil]];
    if (!_prompt)
        [self showNext];
}

- (void)finish:(NSDictionary *)result {
    void (^reply)(NSDictionary *) = [[_reply retain] autorelease];
    [_reply release];
    _reply = nil;
    [_prompt release];
    _prompt = nil;
    [_alert setDelegate:nil];
    [_alert release];
    _alert = nil;
    [_sheet release];
    _sheet = nil;
    if (reply)
        reply(result);
    // The next one after this run loop turn: UIKit is still closing a dialog.
    [self performSelector:@selector(showNext) withObject:nil afterDelay:0.3];
}

- (void)dismissPrompt:(NSString *)promptId {
    if ([LFString([_prompt objectForKey:@"id"]) isEqualToString:promptId]) {
        if (_alert)
            [_alert dismissWithClickedButtonIndex:-1 animated:YES];
        else if (_sheet)
            [_sheet dismissModalViewControllerAnimated:YES];
        [self finish:nil];
        return;
    }
    for (NSArray *pending in [[_queue copy] autorelease])
        if ([LFString([[pending objectAtIndex:0] objectForKey:@"id"]) isEqualToString:promptId]) {
            ((void (^)(NSDictionary *))[pending objectAtIndex:1])(nil);
            [_queue removeObject:pending];
        }
}

- (void)presentSheet:(UIViewController *)controller {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    [nav setModalPresentationStyle:UIModalPresentationFormSheet];
    _sheet = [nav retain];
    [_host presentModalViewController:nav animated:YES];
    [nav release];
}

- (void)alertWithTitle:(NSString *)title message:(NSString *)message style:(UIAlertViewStyle)style
                cancel:(NSString *)cancel ok:(NSString *)ok {
    _alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
                              cancelButtonTitle:cancel otherButtonTitles:ok, nil];
    if (style != UIAlertViewStyleDefault && [_alert respondsToSelector:@selector(setAlertViewStyle:)])
        [_alert setAlertViewStyle:style];
    [_alert show];
}

- (void)showNext {
    if (_prompt || ![_queue count])
        return;
    NSArray *next = [[[_queue objectAtIndex:0] retain] autorelease];
    [_queue removeObjectAtIndex:0];
    _prompt = [[next objectAtIndex:0] retain];
    _reply = [[next objectAtIndex:1] copy];

    NSString *type = LFString([_prompt objectForKey:@"type"]);
    NSString *title = LFString([_prompt objectForKey:@"title"]);
    // Gecko's English default title; the message speaks for itself.
    if ([title isEqualToString:@"This page says:"])
        title = nil;
    NSString *msg = LFString([_prompt objectForKey:@"msg"]);
    LFPrompter *me = self;

    if ([type isEqualToString:@"alert"]) {
        [self alertWithTitle:title message:msg style:UIAlertViewStyleDefault cancel:nil ok:@"OK"];
    } else if ([type isEqualToString:@"button"]) {
        [self alertWithTitle:title message:msg style:UIAlertViewStyleDefault cancel:@"Отмена" ok:@"OK"];
    } else if ([type isEqualToString:@"text"]) {
        [self alertWithTitle:title message:msg style:UIAlertViewStylePlainTextInput cancel:@"Отмена" ok:@"OK"];
        if ([_alert respondsToSelector:@selector(textFieldAtIndex:)])
            [[_alert textFieldAtIndex:0] setText:LFString([_prompt objectForKey:@"value"])];
    } else if ([type isEqualToString:@"auth"]) {
        BOOL passwordOnly = [LFString([_prompt objectForKey:@"mode"]) isEqualToString:@"password"];
        [self alertWithTitle:title ? title : @"Нужен вход" message:msg
                       style:passwordOnly ? UIAlertViewStyleSecureTextInput : UIAlertViewStyleLoginAndPasswordInput
                      cancel:@"Отмена" ok:@"Войти"];
        NSDictionary *options = [_prompt objectForKey:@"options"];
        if (!passwordOnly && [_alert respondsToSelector:@selector(textFieldAtIndex:)])
            [[_alert textFieldAtIndex:0] setText:LFString([options objectForKey:@"username"])];
    } else if ([type isEqualToString:@"repost"]) {
        [self alertWithTitle:@"Отправить форму ещё раз?"
                     message:@"Страница снова отправит данные, которые вы ввели (например, повторит покупку)."
                       style:UIAlertViewStyleDefault cancel:@"Отмена" ok:@"Отправить"];
    } else if ([type isEqualToString:@"beforeUnload"]) {
        [self alertWithTitle:@"Покинуть страницу?" message:@"Введённые данные могут не сохраниться."
                       style:UIAlertViewStyleDefault cancel:@"Остаться" ok:@"Покинуть"];
    } else if ([type isEqualToString:@"popup"]) {
        [self alertWithTitle:@"Всплывающее окно"
                     message:[NSString stringWithFormat:@"Сайт хочет открыть окно:\n%@",
                                 LFString([_prompt objectForKey:@"targetUri"]) ?: @""]
                       style:UIAlertViewStyleDefault cancel:@"Запретить" ok:@"Разрешить"];
    } else if ([type isEqualToString:@"choice"]) {
        NSString *mode = LFString([_prompt objectForKey:@"mode"]);
        LFChoiceController *c = [[LFChoiceController alloc]
            initWithChoices:[_prompt objectForKey:@"choices"]
                   multiple:[mode isEqualToString:@"multiple"]
                       done:^(NSArray *ids) {
                           [me finish:ids ? [NSDictionary dictionaryWithObject:ids forKey:@"choices"] : nil];
                       }];
        [c setTitle:[title length] ? title : @"Выберите"];
        [self presentSheet:c];
        [c release];
    } else if ([type isEqualToString:@"datetime"]) {
        LFDateController *c = [[LFDateController alloc]
            initWithMode:LFString([_prompt objectForKey:@"mode"])
                   value:LFString([_prompt objectForKey:@"value"])
                    done:^(NSString *value) {
                        [me finish:value ? [NSDictionary dictionaryWithObject:value forKey:@"datetime"] : nil];
                    }];
        [self presentSheet:c];
        [c release];
    } else if ([type isEqualToString:@"Autocomplete:Save:Login"]) {
        NSDictionary *login = [[_prompt objectForKey:@"logins"] isKindOfClass:[NSArray class]]
                                  ? [[_prompt objectForKey:@"logins"] lastObject] : nil;
        NSString *site = [[NSURL URLWithString:LFString([login objectForKey:@"origin"])] host];
        NSString *user = LFString([login objectForKey:@"username"]);
        // As Safari asked on iOS 6.
        [self alertWithTitle:@"Сохранить пароль?"
                     message:[user length] ? [NSString stringWithFormat:@"Для «%@» на %@", user, site ?: @"этом сайте"]
                                           : [NSString stringWithFormat:@"Для %@", site ?: @"этого сайта"]
                       style:UIAlertViewStyleDefault cancel:@"Не сейчас" ok:@"Сохранить"];
    } else if ([type isEqualToString:@"Autocomplete:Select:Login"]) {
        NSArray *options = [_prompt objectForKey:@"options"];
        NSMutableArray *choices = [NSMutableArray array];
        for (NSUInteger i = 0; i < [options count]; i++) {
            NSDictionary *login = [[options objectAtIndex:i] objectForKey:@"value"];
            NSString *user = LFString([login objectForKey:@"username"]);
            [choices addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                [user length] ? user : @"(без имени)", @"label",
                [NSString stringWithFormat:@"%u", (unsigned)i], @"id", nil]];
        }
        LFChoiceController *c = [[LFChoiceController alloc] initWithChoices:choices multiple:NO done:^(NSArray *ids) {
            NSDictionary *chosen = ids ? [options objectAtIndex:[[ids lastObject] intValue]] : nil;
            [me finish:chosen ? [NSDictionary dictionaryWithObject:chosen forKey:@"selection"] : nil];
        }];
        [c setTitle:@"Войти как"];
        [self presentSheet:c];
        [c release];
    } else {
        // file, color, share and the rest: not offered yet; the page carries on.
        [self finish:nil];
    }
}

- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)index {
    NSString *type = LFString([_prompt objectForKey:@"type"]);
    BOOL ok = index != [alert cancelButtonIndex];
    NSDictionary *result = nil;
    if ([type isEqualToString:@"alert"]) {
        result = [NSDictionary dictionary];
    } else if ([type isEqualToString:@"button"]) {
        result = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:ok ? 0 : 2] forKey:@"button"];
    } else if ([type isEqualToString:@"text"]) {
        if (ok)
            result = [NSDictionary dictionaryWithObject:[[alert textFieldAtIndex:0] text] ?: @"" forKey:@"text"];
    } else if ([type isEqualToString:@"auth"]) {
        if (ok) {
            BOOL passwordOnly = [LFString([_prompt objectForKey:@"mode"]) isEqualToString:@"password"];
            NSString *user = passwordOnly ? @"" : [[alert textFieldAtIndex:0] text];
            NSString *pass = [[alert textFieldAtIndex:passwordOnly ? 0 : 1] text];
            result = [NSDictionary dictionaryWithObjectsAndKeys:user ?: @"", @"username", pass ?: @"", @"password", nil];
        }
    } else if ([type isEqualToString:@"repost"] || [type isEqualToString:@"popup"]) {
        result = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:ok] forKey:@"response"];
    } else if ([type isEqualToString:@"beforeUnload"]) {
        result = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:ok] forKey:@"allow"];
    } else if ([type isEqualToString:@"Autocomplete:Save:Login"] && ok) {
        id login = [[_prompt objectForKey:@"logins"] lastObject];
        if (login)
            result = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:login forKey:@"value"]
                                                 forKey:@"selection"];
    }
    [self finish:result];
}

- (void)confirmForTesting {
    [_alert dismissWithClickedButtonIndex:[_alert firstOtherButtonIndex] animated:NO];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_alert setDelegate:nil];
    [_alert release];
    [_sheet release];
    [_queue release];
    [_prompt release];
    [_reply release];
    [super dealloc];
}

@end
