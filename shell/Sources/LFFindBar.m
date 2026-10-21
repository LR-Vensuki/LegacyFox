#import "LFFindBar.h"

@implementation LFFindBar

- (id<LFFindBarDelegate>)delegate { return _findDelegate; }
- (void)setDelegate:(id<LFFindBarDelegate>)delegate { _findDelegate = delegate; }

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setBarStyle:UIBarStyleBlack];
        [self setTranslucent:YES];

        _arrows = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Назад", @"Далее", nil]];
        [_arrows setSegmentedControlStyle:UISegmentedControlStyleBar];
        [_arrows setMomentary:YES];
        [_arrows setTintColor:[UIColor darkGrayColor]];
        [_arrows addTarget:self action:@selector(arrow) forControlEvents:UIControlEventValueChanged];

        _field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 31)];
        [_field setBorderStyle:UITextBorderStyleRoundedRect];
        [_field setFont:[UIFont systemFontOfSize:15]];
        [_field setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [_field setPlaceholder:@"Найти на странице"];
        [_field setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_field setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_field setReturnKeyType:UIReturnKeySearch];
        [_field setDelegate:self];
        [_field addTarget:self action:@selector(changed) forControlEvents:UIControlEventEditingChanged];
        // How many matches, at the end of the field.
        _count = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 90, 20)];
        [_count setBackgroundColor:[UIColor clearColor]];
        [_count setTextColor:[UIColor grayColor]];
        [_count setFont:[UIFont systemFontOfSize:13]];
        [_count setTextAlignment:UITextAlignmentRight];
        [_field setRightView:_count];
        [_field setRightViewMode:UITextFieldViewModeAlways];
        _fieldItem = [[UIBarButtonItem alloc] initWithCustomView:_field];

        UIBarButtonItem *arrows = [[UIBarButtonItem alloc] initWithCustomView:_arrows];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self action:@selector(close)];
        [self setItems:[NSArray arrayWithObjects:arrows, _fieldItem, done, nil]];
        [arrows release];
        [done release];
    }
    return self;
}

- (void)layoutSubviews {
    CGFloat w = [self bounds].size.width;
    [_field setFrame:CGRectMake(0, 0, MAX(120, w - 120 - 70 - 40), 31)];
    [super layoutSubviews];
}

- (NSString *)text { return [_field text]; }
- (void)beginEditing { [_field becomeFirstResponder]; }
- (BOOL)isEditing { return [_field isEditing]; }

- (void)setCurrent:(NSInteger)current total:(NSInteger)total found:(BOOL)found {
    if (![[_field text] length])
        [_count setText:nil];
    else if (!found)
        [_count setText:@"Не найдено  "];
    else if (total > 0)
        [_count setText:[NSString stringWithFormat:@"%d из %d  ", (int)current, (int)total]];
    else
        [_count setText:nil];
}

- (void)changed {
    [_findDelegate findBar:self find:[_field text] backwards:NO];
}

- (void)arrow {
    [_findDelegate findBar:self find:nil backwards:[_arrows selectedSegmentIndex] == 0];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
    [field resignFirstResponder];
    return NO;
}

- (void)close {
    [_field resignFirstResponder];
    [_findDelegate findBarDidClose:self];
}

- (void)dealloc {
    [_field setDelegate:nil];
    [_field release];
    [_count release];
    [_arrows release];
    [_fieldItem release];
    [super dealloc];
}

@end
