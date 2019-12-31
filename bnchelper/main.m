#import <Foundation/Foundation.h>
#import <spawn.h>
#import <errno.h>
#import <string.h>

int main(int argc, char **argv) {
	if ((argc <= 1) || (argv[1][0] != '-') || (argv[1][2] != 0)) return 1;
	NSLog(@"[BNCH] Spawned. UID:%d, EUID:%d, GID:%d", getuid(), geteuid(), getgid());
	setuid(0);
	setuid(0);
	seteuid(0);
	seteuid(0);
	setgid(0);
	setgid(0);
	NSLog(@"[BNCH] New UID:%d, EUID:%d, GID:%d", getuid(), geteuid(), getgid());
	const char *proc_argv[] = {
		"/sbin/launchctl",
		NULL,
		"/Library/LaunchDaemons/com.openssh.sshd.plist",
		NULL
	};
	const char *proc_envp[] = {
		"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
		NULL
	};
	errno = 0;
	pid_t pid;
	NSLog(@"[BNCH] Command: %c", argv[1][1]);
	switch (argv[1][1]) {
		case RootCommandRestartSSH: // Restart SSHD
			proc_argv[1] = "load";
			break;
		case RootCommandKillSSH: // Kill SSHD
			#if !DEBUG
				// If not debugging, kill SSHD.
				proc_argv[1] = "unload";
			#else
				// If debugging, don't do so since it is necessary to rejailbreak if I do kill it.
				return 0;
			#endif
			break;
		case RootCommandUninstall:
			proc_argv[0] = "/usr/bin/dpkg";
			proc_argv[1] = "-r";
			proc_argv[2] = "com.pixelomer.bnc";
			break;
	}
	if (!posix_spawn(
		&pid, (char *)proc_argv[0],
		NULL, NULL, (char * const *)proc_argv,
		(char * const *)proc_envp
	)) waitpid(pid, NULL, 0);
	else {
		NSLog(@"[BNCH] Failed to execute process: %s (%s)", proc_argv[0], strerror(errno));
		return 1;
	}
	return 0;
















}
