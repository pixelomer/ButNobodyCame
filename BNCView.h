#import <UIKit/UIKit.h>

@interface BNCView : UIView
@property (nonatomic, strong, readonly) UILabel *label;
- (void)centerText;
- (void)animateString:(NSString *)text completion:(void(^)(void))completion;
- (void)animateStrings:(NSArray<NSString *> *)array delay:(NSTimeInterval)delay completion:(void(^)(void))completion;
- (void)prepareTextAnimation;
@end