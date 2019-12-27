#import "BNCViewController.h"
#import "BNCDelegate.h"
#import <unistd.h>

@implementation BNCDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_rootViewController = [BNCViewController new];
	_window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];
}

@end