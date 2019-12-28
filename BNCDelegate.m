#import "BNCViewController.h"
#import "BNCDelegate.h"
#import <unistd.h>

@implementation BNCDelegate

- (void)viewControllerInitialize {
	_rootViewController = [BNCViewController new];
	_window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];
	// This method is hooked
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	if (!_window) {
		_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
		[self viewControllerInitialize];
	}
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
	if (!_window) {
		_window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
		[self viewControllerInitialize];
	}
}

@end