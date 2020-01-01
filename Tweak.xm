#import <Foundation/Foundation.h>
#import "BNCDelegate.h"
#import "BNCViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <spawn.h>
#import "data/data.h"

#define SIG_COUNT 9

typedef void (*sighandler_t)(int);

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
static int8_t currentSoundIndex = -1;
static const int signals[SIG_COUNT] = {
	SIGQUIT, SIGILL,
	SIGTRAP, SIGABRT,
	SIGEMT, SIGFPE,
	SIGBUS, SIGSEGV,
	SIGSYS
};
static sighandler_t oldSignals[SIG_COUNT];
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

@interface UIWindow(VisibilityHook)
@property (nonatomic, assign) BOOL preventFromShowing;
@end

@interface WGWidgetPlatterView : UIView
@property (nonatomic, strong) BNCView *tweakView;
@property (nonatomic) __weak WGWidgetHostingViewController *widgetHost;
@end

%group SpringBoardPhase2
%hook UIWindow
- (void)setUserInteractionEnabled:(BOOL)isIt {}
%end
%hook _UISystemGestureWindow
- (id)hitTest:(CGPoint)arg1 withEvent:(id)arg2 {
	return nil;
}
%end
%hook SBHomeHardwareButton
- (void)initialButtonDown:(id)arg1 {}
- (void)initialButtonUp:(id)arg1 {}
- (void)singlePressUp:(id)arg1 {}
- (void)acceleratedSinglePressUp:(id)arg1 {}
- (void)doublePressDown:(id)arg1 {}
- (void)doublePressUp:(id)arg1 {}
- (void)triplePressUp:(id)arg1 {}
- (void)doubleTapUp:(id)arg1 {}
- (void)screenshotRecognizerDidRecognize:(id)arg1 {}
- (BOOL)isButtonDown { return NO; }
- (void)longPress:(id)arg1 {}
- (void)_singlePressUp:(id)arg1 {}
%end
%hook SBLockHardwareButton
- (void)singlePress:(id)arg1 {}
- (void)doublePress:(id)arg1 {}
- (void)triplePress:(id)arg1 {}
- (void)quadruplePress:(id)arg1 {}
- (BOOL)isButtonDown { return NO; }
- (void)longPress:(id)arg1 {}
- (void)buttonDown:(id)arg1 {}
%end
%end

static BOOL BNCExecuteRootCommand(const char commandCharacter) {
	pid_t pid;
	char arg[3];
	const char *proc_argv[] = {
		"/usr/local/bin/bnchelper",
		arg,
		NULL
	};
	arg[0] = '-';
	arg[1] = commandCharacter;
	arg[2] = 0;
	BOOL success;
	if (!posix_spawn(
		&pid, (char *)proc_argv[0],
		NULL, NULL, (char * const *)proc_argv,
		(char * const *)&proc_argv[2]
	)) {
		int status;
		waitpid(pid, &status, 0);
		if ((success = WIFEXITED(status))) {
			if (commandCharacter == RootCommandTestAvailability) {
				success = (WEXITSTATUS(status) == RET_BNC_AVAILABLE);
			}
			else {
				success = !WEXITSTATUS(status);
			}
		}
	} else success = NO;
	if (!success && ((commandCharacter == RootCommandUninstall) || (commandCharacter == RootCommandTestAvailability))) {
		[NSException
			raise:NSInternalInconsistencyException
			format:@"Extremely descriptive error message: Something went wrong."
		];
	}
	return success;
}

static void BNCHandleDeleteNotification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	for (int i=0; i<SIG_COUNT; i++) if (oldSignals[i]) {
		signal(signals[i], oldSignals[i]);
	}
	BNCExecuteRootCommand(RootCommandRestartSSH);
	BNCExecuteRootCommand(RootCommandUninstall);
	CFNotificationCenterRemoveObserver(
		notifCenter,
		NULL,
		RespringNotification,
		NULL
	);
	CFNotificationCenterPostNotification(
		notifCenter,
		RespringNotification,
		NULL,
		NULL,
		YES
	);
	exit(0);
}

static void BNCHandlePhaseNotification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	NSString *name = (__bridge NSString *)cfname;
	uint8_t soundIndex = ([name characterAtIndex:(name.length-1)] - '1');
	if (soundIndex <= currentSoundIndex) return;
	if ((currentSoundIndex = soundIndex)) {
		[windowArray compact];
		%init(SpringBoardPhase2);
		for (UIWindow *window in windowArray.allObjects) {
			window.userInteractionEnabled = NO;
		}
		if (!preventAutolockTimer) preventAutolockTimer = [NSTimer
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

static void BNCHandleRespringNotification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	exit(0);
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

%group ClientLastQuestion
%hook BNCDelegate
- (void)handleVolumeUp {
	[self.rootViewController.view
		animateStrings:@[
			@"...",
			@"Then, it is done.\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07", // 1 second extra delay
			@" \x07\x07\x07\x07" // half a second of black
		]
		delay:1.0
		completion:^{
			[self.rootViewController.view.label setText:@(
				"     === Credits ===      \n"
				"@pixelomer (iOS tweak)    \n"
				"@tobyfox (UNDERTALE, font,\n"
				"          audio)          \n"
				"@conorthedev (widgets)    \n"
			)];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*3), dispatch_get_main_queue(), ^{
				CFNotificationCenterPostNotification(
					notifCenter,
					DeleteNotification,
					NULL,
					NULL,
					YES
				);
			});
		}
	];
}
%end
%end

%group ClientPhase3
%hook BNCDelegate
- (void)continueDialogue {
	CFNotificationCenterPostNotification(
		notifCenter,
		Phase3Notification,
		NULL,
		NULL,
		YES
	);
	[self.rootViewController.view animateStrings:@[
		@"Then it is agreed.",
		@"You will give me your\n\x07\x07\x07ROOT PASSWORD."
	] delay:1.0 completion:^{
		%init(ClientLastQuestion);
		self.rootViewController.view.option1Label.text = @"YES (Vol.Up)  ";
		self.rootViewController.view.option2Label.text = @"NO  (Vol.Down)";
		self.handleVolumeButtons = YES;
	}];
}
- (void)handleVolumeUp {
	[self continueDialogue];
}
- (void)handleVolumeDown {
	[self.rootViewController.view animateString:@"Then stay here for an\neternity." completion:^{
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			usleep(1000000);
			dispatch_async(dispatch_get_main_queue(), ^{
				CFNotificationCenterPostNotification(
					notifCenter,
					RespringNotification,
					NULL,
					NULL,
					YES
				);
			});
		});
	}];
}

%end
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
- (void)continueDialogue {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[self.rootViewController.view animateStrings:@[
			@" \x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07",
			@"Perhaps.",
			@"We can reach a compromise.",
			@"You still have something\nI want.",
			@"Give it to me.",
			@"And I will bring your\ndevice back.",
			@" "
		] delay:1.0 completion:^{
			%init(ClientPhase3);
			self.rootViewController.view.option1Label.text = @"YES (Vol.Up)  ";
			self.rootViewController.view.option2Label.text = @"NO  (Vol.Down)";
			self.handleVolumeButtons = YES;
		}];
	});
}
- (void)handleVolumeUp {
	[self.rootViewController.view animateString:@"Exactly." completion:^{
		[self continueDialogue];
	}];
}
- (void)handleVolumeDown {
	[self.rootViewController.view animateString:@"Then what are you looking\nfor?" completion:^{
		[self continueDialogue];
	}];
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
			#define audioLevel 0.45
			if (%c(VolumeControl)) {
				((VolumeControl *)[%c(VolumeControl) sharedVolumeControl]).mediaVolume = audioLevel;
			}
			else {
				((VolumeControl *)[%c(SBVolumeControl) sharedInstance]).activeCategoryVolume = audioLevel;
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
%hook UIWindow
%property (nonatomic, assign) BOOL preventFromShowing;

- (void)setHidden:(BOOL)hidden {
	if (self.preventFromShowing) %orig(YES);
	else %orig;
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
	notifCenter = CFNotificationCenterGetDarwinNotifyCenter();
	if (![blacklistedApps containsObject:NSBundle.mainBundle.bundleIdentifier] && NSBundle.mainBundle.bundleIdentifier.length) {
		if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
			// RootCommandTestAvailability:
			// - Runs the bnchelper command to make sure that it works properly.
			//   if it doesn't, SpringBoard will crash into safe mode. This has
			//   to be done since otherwise it'd be impossible to escape.
			BNCExecuteRootCommand(RootCommandTestAvailability);
			const char *proc_argv[] = {
				"/usr/bin/killall",
				"Spotlight",
				NULL
			};
			posix_spawn(
				NULL, (char *)proc_argv[0],
				NULL, NULL, (char * const *)proc_argv,
				(char * const *)&proc_argv[2]
			);
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
			CFNotificationCenterAddObserver(
				notifCenter, NULL,
				&BNCHandlePhaseNotification,
				Phase3Notification,
				NULL, 0
			);
			CFNotificationCenterAddObserver(
				notifCenter, NULL,
				&BNCHandleRespringNotification,
				RespringNotification,
				NULL, 0
			);
			CFNotificationCenterAddObserver(
				notifCenter, NULL,
				&BNCHandleDeleteNotification,
				DeleteNotification,
				NULL, 0
			);
			[NSNotificationCenter.defaultCenter
				addObserverForName:UIWindowDidBecomeVisibleNotification
				object:nil
				queue:nil
				usingBlock:^(NSNotification *notif){
					if ((currentSoundIndex >= 1) || [notif.object isKindOfClass:%c(SBHUDWindow)]) {
						[(UIWindow *)notif.object setPreventFromShowing:YES];
						[(UIWindow *)notif.object setHidden:YES];
					}
				}
			];
			for (int i=0; i<SIG_COUNT; i++) {
				// Disable safe mode signals.
				sighandler_t sig = signal(signals[i], SIG_DFL);
				if (sig != SIG_ERR) oldSignals[i] = NULL;
				else oldSignals[i] = sig;
			}
			BNCExecuteRootCommand(RootCommandKillSSH);
			%init(Server);
		}
		else {
			NSString *bpath = NSBundle.mainBundle.bundlePath;
			if ([bpath hasPrefix:@"/var"] || [bpath hasPrefix:@"/private/var"] || [bpath hasPrefix:@"/Applications"]) {
				phase2IDs = @[
					@"com.saurik.Cydia",
					@"xyz.willy.Zebra",
					@"me.apptapp.installer",
					@"com.notdan.Lime",
					@"org.coolstar.SileoStore"
				];
				blockedKeys = @[
					@"UIApplicationSupportsMultipleScenes",
					@"UISceneConfigurations"
				];
				%init(Client);
			}
		}
	}
	else {
		CFNotificationCenterAddObserver(
			notifCenter, NULL,
			&BNCHandleRespringNotification,
			RespringNotification,
			NULL, 0
		);
	}
}