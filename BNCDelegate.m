#import "BNCViewController.h"
#import "BNCDelegate.h"
#import <unistd.h>

static void BNCHandleButtonNotification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *unused,
	CFDictionaryRef userInfo
) {
	BNCDelegate *self = (__bridge id)observer;
	NSString *name = (__bridge NSString *)cfname;
	[self _handleVolumeButton:([name characterAtIndex:(name.length-1)] == 'n')];
}

@implementation BNCDelegate

- (void)continueDialogue {
	// Hooked by Tweak.xm
}

- (void)_handleVolumeButton:(BOOL)volumeDownButton {
	@synchronized (self) {
		if (_handleVolumeButtons) {
			_handleVolumeButtons = NO;
			NSString *selectorSuffix = volumeDownButton ? @"Down" : @"Up";
			SEL selector = NSSelectorFromString([@"handleVolume" stringByAppendingString:selectorSuffix]);
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				dispatch_sync(dispatch_get_main_queue(), ^{
					UILabel *label = (volumeDownButton ?
						self.rootViewController.view.option2Label :
						self.rootViewController.view.option1Label
					);
					label.textColor = [UIColor yellowColor];
				});
				usleep(1500000);
				dispatch_async(dispatch_get_main_queue(), ^{
					self.rootViewController.view.option1Label.text =
					self.rootViewController.view.option2Label.text = @"";
					self.rootViewController.view.option1Label.textColor =
					self.rootViewController.view.option2Label.textColor = [UIColor whiteColor];
					[self performSelector:selector];
				});
			});
		}
	}
}

- (void)handleVolumeDown {
	// Hooked by Tweak.xm
}

- (void)handleVolumeUp {
	// Hooked by Tweak.xm
}

- (void)setHandleVolumeButtons:(BOOL)should {
	@synchronized (self) {
		_handleVolumeButtons = should;
	}
}

- (void)viewControllerInitialize {
	_rootViewController = [BNCViewController new];
	_window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];
	CFNotificationCenterRef notifCenter = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(
		notifCenter, (void *)self,
		&BNCHandleButtonNotification,
		VolUpNotification,
		NULL, 0
	);
	CFNotificationCenterAddObserver(
		notifCenter, (void *)self,
		&BNCHandleButtonNotification,
		VolDownNotification,
		NULL, 0
	);
	// Hooked by Tweak.xm
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