#import <Foundation/Foundation.h>
#import <spawn.h>

static BOOL stay_alive = NO;
static char *launchctl_argv[4];
static CFNotificationCenterRef notifCenter;

static void check_stay_alive(void) {
	if (!stay_alive) {
		launchctl_argv[1] = "load";
		posix_spawn(
			NULL, launchctl_argv[0],
			NULL, NULL, launchctl_argv,
			&launchctl_argv[3]
		);
		exit(0);
	}
	else {
		stay_alive = NO;
	}
}

static void handle_stay_alive_notification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	stay_alive = YES;
}

static void handle_suicide_notification(
	CFNotificationCenterRef center,
	void *observer,
	CFNotificationName cfname,
	const void *object,
	CFDictionaryRef userInfo
) {
	CFNotificationCenterPostNotification(
		notifCenter,
		RespringNotification,
		NULL,
		NULL,
		YES
	);
}

int main(int argc, char **argv) {
	const char *launchctl_argv_const[4] = { "/sbin/launchctl", "unload", "/Library/LaunchDaemons/com.openssh.sshd.plist", NULL };
	memcpy(launchctl_argv, launchctl_argv_const, sizeof(launchctl_argv_const));
	setuid(0);
	setuid(0);
	seteuid(0);
	seteuid(0);
	setgid(0);
	setgid(0);
	posix_spawn(
		NULL, launchctl_argv[0],
		NULL, NULL, launchctl_argv,
		&launchctl_argv[3]
	);
	CFNotificationName stayAliveNotification = (CFNotificationName)CFBridgingRetain(
		[NSString stringWithFormat:@"%@%d", StayAliveNotificationPrefix, getpid()]
	);
	CFNotificationName deleteNotification = (CFNotificationName)CFBridgingRetain(
		[NSString stringWithFormat:@"%@%d", DeleteNotificationPrefix, getpid()]
	);
	notifCenter = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(
		notifCenter, NULL,
		&handle_stay_alive_notification,
		stayAliveNotification,
		NULL, 0
	);
	CFNotificationCenterAddObserver(
		notifCenter, NULL,
		&handle_suicide_notification,
		deleteNotification,
		NULL, 0
	);
	NSTimer * __unused checkStayAlive = [NSTimer
		scheduledTimerWithTimeInterval:5.0
		repeats:YES
		block:^(NSTimer *timer){ check_stay_alive(); }
	];
	while (1) {
		[NSRunLoop.currentRunLoop run];
	}
}
