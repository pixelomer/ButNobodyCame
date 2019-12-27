#import <UIKit/UIKit.h>

@class BNCViewController;

@interface BNCDelegate : UIResponder<UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) BNCViewController *rootViewController;
@end