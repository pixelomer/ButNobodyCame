#import <UIKit/UIKit.h>

@class BNCViewController;

@interface BNCDelegate : UIResponder<UIApplicationDelegate, UISceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) BNCViewController *rootViewController;
@end