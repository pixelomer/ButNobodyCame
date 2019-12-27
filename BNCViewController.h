#import <UIKit/UIKit.h>

@interface BNCViewController : UIViewController
@property (nonatomic, strong) UILabel *label;
- (void)centerText;
- (void)animateString:(NSString *)text completion:(void(^)(void))completion;
- (void)animateStrings:(NSArray<NSString *> *)array delay:(NSTimeInterval)delay completion:(void(^)(void))completion;
- (void)prepareTextAnimation;
@end