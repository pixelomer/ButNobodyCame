#import <Foundation/Foundation.h>
#import "BNCDelegate.h"
#import "BNCViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "data/data.h"

static AVAudioPlayer *audioPlayer;
static id sharedReceiver;
static NSArray *phase2IDs;
static NSArray *blockedKeys;
static NSArray *blacklistedApps;
static CFNotificationCenterRef notifCenter;
static uint8_t phase1Sound[] = PHASE1_SOUND;
static uint8_t phase2Sound[] = PHASE2_SOUND;
static struct {
	uint8_t *data;
	size_t size;
} sounds[] = {
	{ phase1Sound, sizeof(phase1Sound) },
	{ phase2Sound, sizeof(phase2Sound) },
};

@interface SBFWallpaperView : UIView
@property (nonatomic, strong) UIView *blackView;
@end

@interface WGWidgetHostingViewController : UIViewController
@property (nonatomic, copy) NSString *appBundleID;
@end

@interface WGWidgetPlatterView : UIView
@property (nonatomic, strong) BNCView *tweakView;
@property (nonatomic) __weak WGWidgetHostingViewController *widgetHost;
@end

static void BNCHandlePhaseNotification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	NSString *name = (__bridge NSString *)cfname;
	uint8_t soundIndex = !!([name characterAtIndex:(name.length-1)] == '2');
	[audioPlayer stop];
	audioPlayer = [[AVAudioPlayer alloc]
		initWithData:[NSData
			dataWithBytesNoCopy:sounds[soundIndex].data
			length:sounds[soundIndex].size
			freeWhenDone:NO
		]
		error:nil
	];
	audioPlayer.numberOfLoops = -1;
	audioPlayer.volume = 1.0;
	[audioPlayer play];
}

@interface VolumeControl : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedVolumeControl;
- (float)volumeStepUp;
- (float)volumeStepDown;
- (void)setMediaVolume:(float)arg1;
- (void)setActiveCategoryVolume:(float)arg1;
@end

%group Client
%hook UISceneConfiguration
- (Class)sceneClass {
	return %c(UIWindowScene);
}
- (Class)delegateClass {
	return %c(BNCDelegate);
}
- (NSString *)name {
	return @"get dunked on";
}
- (UIStoryboard *)storyboard {
	return nil;
}
%end

%hook UIStoryboard
+ (id)alloc {
	return nil;
}
%end
%hook BNCDelegate
- (void)viewControllerInitialize {
	%orig;
	if ([phase2IDs containsObject:NSBundle.mainBundle.bundleIdentifier]) {
		CFNotificationCenterPostNotification(
			notifCenter,
			Phase2Notification,
			NULL,
			NULL,
			YES
		);
		[self.rootViewController.view prepareTextAnimation];
		[self.rootViewController.view animateStrings:@[
			@"Interesting.    ",
			@"You want to go back.",
			@"You want to go back to\nthe device \x07\x07\x07\x07you destroyed.",
			@"It was you who pushed\neverything \x07\x07\x07\x07to its edge.",
			@"It was you who led this\ndevice \x07\x07\x07\x07to its destruction.",
			@"But you cannot accept it."
		] delay:1.0 completion:nil];
	}
	else {
		/*
		CFNotificationCenterPostNotification(
			notifCenter,
			Phase1Notification,
			NULL,
			NULL,
			YES
		);
		*/
		[self.rootViewController.view centerText];
		[self.rootViewController.view.label setText:@"But nobody came."];
	}
}
%end

%hookf(int, UIApplicationMain, int argc, char **argv, NSString *principalClassName, NSString *delegateClassName) {
	return %orig(argc, argv, NSStringFromClass(UIApplication.class), NSStringFromClass(BNCDelegate.class));
}

%hookf(int, "main", int argc, char **argv) {
	return UIApplicationMain(argc, argv, nil, nil);
}
%end

%group Server
%hook WGWidgetPlatterView
%property (nonatomic, strong) BNCView *tweakView;

- (void)_setContentView:(UIView *)view {
	if (!self.widgetHost.appBundleID.length) %orig;
	if (!self.tweakView) {
		self.tweakView = [BNCView new];
		self.tweakView.backgroundColor = [UIColor clearColor];
		self.tweakView.label.textColor = [UIColor labelColor];
		[self.tweakView centerText];
		[self.tweakView.label setText:@"But nobody came."];
	}
	%orig(self.tweakView);
}

%end
%hook SBFWallpaperView
%property (nonatomic, strong) UIView *blackView;

- (void)didMoveToWindow {
	if (!self.blackView) {
		self.blackView = [UIView new];
		self.blackView.backgroundColor = [UIColor blackColor];
		self.blackView.translatesAutoresizingMaskIntoConstraints = NO;
		for (UIView *view in [self subviews]) {
			[view removeFromSuperview];
		}
		[self addSubview:self.blackView];
		[self.blackView.heightAnchor constraintEqualToAnchor:self.heightAnchor].active =
		[self.blackView.widthAnchor constraintEqualToAnchor:self.widthAnchor].active =
		[self.blackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active =
		[self.blackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
		if (!audioPlayer) {
			if (%c(VolumeControl)) {
				((VolumeControl *)[%c(VolumeControl) sharedVolumeControl]).mediaVolume = 0.65;
			}
			else {
				((VolumeControl *)[%c(SBVolumeControl) sharedInstance]).activeCategoryVolume = 0.65;
			}
			BNCHandlePhaseNotification(NULL, NULL, Phase1Notification, NULL, NULL);
		}
	}
}

- (void)addSubview:(UIView *)subview {
	if (!self.blackView || (subview == self.blackView)) %orig;
}

%end
%end

%ctor {
	blacklistedApps = @[
		@"com.apple.Spotlight"
	];
	if (![blacklistedApps containsObject:NSBundle.mainBundle.bundleIdentifier] && NSBundle.mainBundle.bundleIdentifier.length) {
		notifCenter = CFNotificationCenterGetDarwinNotifyCenter();
		if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
			CFNotificationCenterAddObserver(
				notifCenter, NULL,
				&BNCHandlePhaseNotification,
				Phase1Notification,
				NULL, 0
			);
			CFNotificationCenterAddObserver(
				notifCenter, NULL,
				&BNCHandlePhaseNotification,
				Phase2Notification,
				NULL, 0
			);
			%init(Server);
		}
		else {
			NSString *bpath = NSBundle.mainBundle.bundlePath;
			if ([bpath hasPrefix:@"/var"] || [bpath hasPrefix:@"/private/var"] || [bpath hasPrefix:@"/Applications"]) {
				phase2IDs = @[
					@"com.saurik.Cydia"
				];
				blockedKeys = @[
					@"UIApplicationSupportsMultipleScenes",
					@"UISceneConfigurations"
				];
				%init(Client);
			}
		}
	}
}