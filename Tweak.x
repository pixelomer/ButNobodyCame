#import <Foundation/Foundation.h>
#import "BNCDelegate.h"
#import "BNCViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <rocketbootstrap/rocketbootstrap.h>

@interface CPDistributedMessagingCenter : NSObject

+ (id)_centerNamed:(id)arg1 requireLookupByPID:(bool)arg2;
+ (id)centerNamed:(id)arg1;
+ (id)pidRestrictedCenterNamed:(id)arg1;

- (void)_dispatchMessageNamed:(id)arg1 userInfo:(id)arg2 reply:(id*)arg3 auditToken:(struct { unsigned int x1[8]; }*)arg4;
- (id)_initAnonymousServer;
- (id)_initClientWithPort:(unsigned int)arg1;
- (id)_initWithServerName:(id)arg1;
- (id)_initWithServerName:(id)arg1 requireLookupByPID:(bool)arg2;
- (bool)_isTaskEntitled:(struct { unsigned int x1[8]; }*)arg1;
- (id)_requiredEntitlement;
- (bool)_sendMessage:(id)arg1 userInfo:(id)arg2 receiveReply:(id*)arg3 error:(id*)arg4 toTarget:(id)arg5 selector:(SEL)arg6 context:(void*)arg7;
- (bool)_sendMessage:(id)arg1 userInfo:(id)arg2 receiveReply:(id*)arg3 error:(id*)arg4 toTarget:(id)arg5 selector:(SEL)arg6 context:(void*)arg7 nonBlocking:(bool)arg8;
- (bool)_sendMessage:(id)arg1 userInfoData:(id)arg2 oolKey:(id)arg3 oolData:(id)arg4 makeServer:(bool)arg5 receiveReply:(id*)arg6 nonBlocking:(bool)arg7 error:(id*)arg8;
- (unsigned int)_sendPort;
- (void)_sendReplyMessage:(id)arg1 portPassing:(bool)arg2 onMachPort:(unsigned int)arg3;
- (unsigned int)_serverPort;
- (void)_setSendPort:(unsigned int)arg1;
- (void)_setupInvalidationSource;
- (void)dealloc;
- (id)delayReply;
- (bool)doesServerExist;
- (id)name;
- (void)registerForMessageName:(id)arg1 target:(id)arg2 selector:(SEL)arg3;
- (void)runServerOnCurrentThread;
- (void)runServerOnCurrentThreadProtectedByEntitlement:(id)arg1;
- (void)sendDelayedReply:(id)arg1 dictionary:(id)arg2;
- (id)sendMessageAndReceiveReplyName:(id)arg1 userInfo:(id)arg2;
- (id)sendMessageAndReceiveReplyName:(id)arg1 userInfo:(id)arg2 error:(id*)arg3;
- (void)sendMessageAndReceiveReplyName:(id)arg1 userInfo:(id)arg2 toTarget:(id)arg3 selector:(SEL)arg4 context:(void*)arg5;
- (bool)sendMessageName:(id)arg1 userInfo:(id)arg2;
- (bool)sendNonBlockingMessageName:(id)arg1 userInfo:(id)arg2;
- (void)setTargetPID:(int)arg1;
- (void)stopServer;
- (void)unregisterForMessageName:(id)arg1;

@end

static AVAudioPlayer *audioPlayer;
static CPDistributedMessagingCenter *messagingCenter;
static id sharedReceiver;
static NSArray *phase2IDs;

@interface SBFWallpaperView : UIView
@property (nonatomic, strong) UIView *blackView;
@end

@interface BNCReceiver : NSObject
+ (id)sharedInstance;
@end

@implementation BNCReceiver
+ (id)sharedInstance {
	return sharedReceiver ?: (sharedReceiver = [self new]);
}
- (void)handleMessageNamed:(NSString *)message withUserInfo:(NSDictionary *)dict {
	if ([message isEqualToString:@"set_sound"]) {
		[audioPlayer stop];
		audioPlayer = [[AVAudioPlayer alloc]
			initWithContentsOfURL:[NSURL fileURLWithPath:dict[@"sound"]]
			error:nil
		];
		audioPlayer.numberOfLoops = -1;
		audioPlayer.volume = 1.0;
		[audioPlayer play];
	}
}
@end

@interface VolumeControl : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedVolumeControl;
- (float)volumeStepUp;
- (float)volumeStepDown;
- (void)setMediaVolume:(float)arg1;
- (void)setActiveCategoryVolume:(float)arg1;
@end

%group Client
%hook BNCDelegate
- (void)applicationDidFinishLaunching:(UIApplication *)application {
	%orig;
	if ([phase2IDs containsObject:NSBundle.mainBundle.bundleIdentifier]) {
		[messagingCenter sendMessageName:@"set_sound" userInfo:@{ @"sound" : @"/Library/ButNobodyCame/sound_2.mp3" }];
		[self.rootViewController prepareTextAnimation];
		[self.rootViewController animateStrings:@[
			@"Interesting.        ",
			@"You want to go back.",
			@"You want to go back to\nthe device you destroyed.",
			@"It was you who pushed\neverything to its edge.",
			@"It was you who led this\ndevice to its destruction.",
			@"But you cannot accept it."
		] delay:1.0 completion:nil];
	}
	else {
		[self.rootViewController centerText];
		[self.rootViewController.label setText:@"But nobody came."];
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
				VolumeControl *instance = [%c(SBVolumeControl) sharedInstance];
				[instance setActiveCategoryVolume:0.65];
			}
			audioPlayer = [[AVAudioPlayer alloc]
				initWithContentsOfURL:[NSURL fileURLWithPath:@"/Library/ButNobodyCame/sound_1.mp3"]
				error:nil
			];
			audioPlayer.numberOfLoops = -1;
			audioPlayer.volume = 1.0;
			[audioPlayer play];
		}
	}
}

- (void)addSubview:(UIView *)subview {
	if (!self.blackView || (subview == self.blackView)) %orig;
}

%end
%end

%ctor {
	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		messagingCenter = [CPDistributedMessagingCenter centerNamed:@"com.pixelomer.badtime"];
		rocketbootstrap_distributedmessagingcenter_apply(messagingCenter);
		[messagingCenter runServerOnCurrentThread];
		[messagingCenter registerForMessageName:@"set_sound" target:BNCReceiver.sharedInstance selector:@selector(handleMessageNamed:withUserInfo:)];
		%init(Server);
	}
	else {
		NSString *bpath = NSBundle.mainBundle.bundlePath;
		if ([bpath hasPrefix:@"/var"] || [bpath hasPrefix:@"/private/var"] || [bpath hasPrefix:@"/Applications"]) {
			phase2IDs = @[
				@"com.saurik.Cydia"
			];
			messagingCenter = [CPDistributedMessagingCenter centerNamed:@"com.pixelomer.badtime"];
			rocketbootstrap_distributedmessagingcenter_apply(messagingCenter);
			%init(Client);
		}
	}
}