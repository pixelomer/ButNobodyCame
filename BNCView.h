#import <UIKit/UIKit.h>

@interface BNCView : UIView
@property (nonatomic, strong, readonly) UILabel *label;
@property (nonatomic, strong, readonly) UILabel *option1Label;
@property (nonatomic, strong, readonly) UILabel *option2Label;
- (void)centerText;
- (void)animateString:(NSString *)text completion:(void(^)(void))completion;
- (void)animateStrings:(NSArray<NSString *> *)array delay:(NSTimeInterval)delay completion:(void(^)(void))completion;
- (void)prepareTextAnimation;
+ (UIFont *)font;
@end