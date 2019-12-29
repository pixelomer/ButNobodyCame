#import <UIKit/UIKit.h>

@class BNCViewController;

@interface BNCDelegate : UIResponder<UIApplicationDelegate, UISceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, assign) BOOL handleVolumeButtons;
@property (nonatomic, strong) BNCViewController *rootViewController;
- (void)_handleVolumeButton:(BOOL)volumeDownButton;
@end