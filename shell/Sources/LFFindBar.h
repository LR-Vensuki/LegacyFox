// Find in page, in the manner of iOS 6: a black bar over the keyboard with
// the search field, previous and next, and Done.

@class LFFindBar;

@protocol LFFindBarDelegate <NSObject>
- (void)findBar:(LFFindBar *)bar find:(NSString *)text backwards:(BOOL)backwards;
- (void)findBarDidClose:(LFFindBar *)bar;
@end

@interface LFFindBar : UIToolbar <UITextFieldDelegate> {
    UITextField *_field;
    UILabel *_count;
    UISegmentedControl *_arrows;
    UIBarButtonItem *_fieldItem;
    id<LFFindBarDelegate> _findDelegate;
}
@property(nonatomic, assign) id<LFFindBarDelegate> delegate;
- (void)setCurrent:(NSInteger)current total:(NSInteger)total found:(BOOL)found;
- (void)beginEditing;
- (BOOL)isEditing;
- (NSString *)text;
@end
