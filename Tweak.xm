#import <Foundation/Foundation.h>
#import "BNCDelegate.h"
#import "BNCViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "data/data.h"

@class SpringBoard;

static AVAudioPlayer *audioPlayer;
static id sharedReceiver;
static NSArray *phase2IDs;
static NSArray *blockedKeys;
static NSTimer *preventAutolockTimer;
static NSPointerArray *windowArray;
static NSArray *blacklistedApps;
static NSDictionary *localizationReplacements;
static CFNotificationCenterRef notifCenter;
static uint8_t phase1Sound[] = PHASE1_SOUND;
static SpringBoard * __strong springboard;
static uint8_t phase2Sound[] = PHASE2_SOUND;
static uint8_t currentSoundIndex = 1;
static struct {
	uint8_t *data;
	size_t size;
} sounds[] = {
	{ phase1Sound, sizeof(phase1Sound) },
	{ phase2Sound, sizeof(phase2Sound) },
	{ NULL, 0 },
};

@interface SpringBoard : NSObject
- (BOOL)isLocked;
@end

@interface SBIdleTimerProxy : NSObject
- (void)reset;
- (id)sourceTimer;
@end

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

%group SpringBoardPhase2
%hook UIWindow
- (void)setUserInteractionEnabled:(BOOL)isIt {
	%orig(NO);
}
%end
%hook _UISystemGestureWindow
- (id)hitTest:(CGPoint)arg1 withEvent:(id)arg2 {
	return nil;
}
%end
%end

static void BNCHandlePhaseNotification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	NSString *name = (__bridge NSString *)cfname;
	uint8_t soundIndex = !!([name characterAtIndex:(name.length-1)] == '2');
	if (soundIndex == currentSoundIndex) return;
	if ((currentSoundIndex = soundIndex)) {
		[windowArray compact];
		%init(SpringBoardPhase2);
		for (UIWindow *window in windowArray.allObjects) {
			window.userInteractionEnabled = NO;
		}
		preventAutolockTimer = [NSTimer
			scheduledTimerWithTimeInterval:10.0
			repeats:YES
			block:^(NSTimer *timer){
				if (!springboard.isLocked) {
					SBIdleTimerProxy *currentTimer = MSHookIvar<id>(springboard, "_idleTimer");
					if (currentTimer) {
						while (currentTimer.class == %c(SBIdleTimerProxy)) {
							currentTimer = currentTimer.sourceTimer;
						}
						[currentTimer reset];
					}
				}
			}
		];
	}
	else {
		[preventAutolockTimer invalidate];
		preventAutolockTimer = nil;
	}
	[audioPlayer stop];
	if (sounds[soundIndex].data) {
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
}

@interface VolumeControl : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedVolumeControl;
- (float)volumeStepUp;
- (float)volumeStepDown;
- (void)setMediaVolume:(float)arg1;
- (void)setActiveCategoryVolume:(float)arg1;
@end

%group Shared
%hook NSBundle
- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)val table:(NSString *)table {
	return (localizationReplacements[key] ?: %orig);
}
%end
%hookf(void *, dlopen, const char *cpath, int mode) {
	if (cpath) {
		NSString *path = @(cpath);
		if ([path containsString:@"TweakInject"] || [path hasPrefix:@"/Library/MobileSubstrate/DynamicLibraries"]) {
			return NULL;
		}
	}
	return %orig;
}
%end

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
		self.handleVolumeButtons = NO;
		[self.rootViewController.view prepareTextAnimation];
		[self.rootViewController.view animateStrings:@[
			@"Interesting.    ",
			@"You want to go back.",
			@"You want to go back to\nthe device \x07\x07\x07\x07you destroyed.",
			@"It was you who pushed\neverything \x07\x07\x07\x07to its edge.",
			@"It was you who led this\ndevice \x07\x07\x07\x07to its destruction.",
			@"But you cannot accept it.",
			@"You think you are above\nconsequences."
		] delay:1.0 completion:^{
			self.rootViewController.view.option1Label.text = @"YES (Vol.Up)  ";
			self.rootViewController.view.option2Label.text = @"NO  (Vol.Down)";
			self.handleVolumeButtons = YES;
		}];
	}
	else {
		CFNotificationCenterPostNotification(
			notifCenter,
			Phase1Notification,
			NULL,
			NULL,
			YES
		);
		[self.rootViewController.view centerText];
		[self.rootViewController.view.label setText:@"But nobody came."];
	}
}
- (void)handleVolumeUp {
	[self.rootViewController.view animateString:@"Exactly." completion:nil];
}
- (void)handleVolumeDown {
	[self.rootViewController.view animateString:@"Then what are you looking\nfor?" completion:nil];
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
%hook SpringBoard
+ (id)alloc {
	id orig = %orig;
	springboard = orig;
	return orig;
}
%end
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
%hook UIWindow

+ (id)alloc {
	id instance = %orig;
	if ((self == %c(FBRootWindow)) || (self == %c(UIRootSceneWindow))) {
		[windowArray addPointer:(void *)instance];
	}
	return instance;
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
%hook CCUIModuleCollectionView
- (id)initWithFrame:(CGRect)frame layoutOptions:(id)opts {
	id instance = %orig;
	[(UIView *)instance setHidden:YES];
	return instance;
}
- (void)setHidden:(BOOL)hidden {
	%orig(YES);
}
%end
%hook SBVolumeHardwareButton

- (void)volumeIncreasePress:(id)arg1 {
	CFNotificationCenterPostNotification(
		notifCenter,
		VolUpNotification,
		NULL,
		NULL,
		YES
	);
}

- (void)volumeDecreasePress:(id)arg1 {
	CFNotificationCenterPostNotification(
		notifCenter,
		VolDownNotification,
		NULL,
		NULL,
		YES
	);
}

%end
%end

%ctor {
	localizationReplacements = @{
		@"DELETE_APP_SHORTCUT_ITEM_TITLE" : @"Murder",
		@"SEARCH_BAR_PLACEHOLDER" : @"Where are the repos"
	};
	windowArray = [NSPointerArray weakObjectsPointerArray];
	%init(Shared); // Block other tweaks
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