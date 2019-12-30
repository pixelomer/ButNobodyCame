#import <Foundation/Foundation.h>

static void kill_sshd(void) {

}

int main(int argc, char **argv) {
	NSTimer * __unused sshdTimer = [NSTimer
		scheduledTimerWithTimeInterval:1.0
		repeats:YES
		block:^(NSTimer *timer){ kill_sshd(); }
	];
	while (1) {
		[NSRunLoop.currentRunLoop run];
	}
}
