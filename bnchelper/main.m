#import <Foundation/Foundation.h>
#import <spawn.h>
#import <errno.h>
#import <string.h>

int main(int argc, char **argv) {
	if ((argc <= 1) || (argv[1][0] != '-') || (argv[1][2] != 0)) return 1;
	setuid(0);
	setuid(0);
	seteuid(0);
	seteuid(0);
	setgid(0);
	setgid(0);
	const char *proc_argv[] = {
		"launchctl",
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
	switch (argv[1][1]) {
		case RootCommandRestartSSH: // Restart SSHD
			proc_argv[1] = "load";
			break;
		case RootCommandKillSSH: // Kill SSHD
			proc_argv[1] = "unload";
			break;
		case RootCommandUninstall:
			proc_argv[0] = "dpkg";
			proc_argv[1] = "-r";
			proc_argv[2] = "com.pixelomer.bnc";
			
			// Manually delete the tweak files, just in case DPKG fails
			unlink("/Library/MobileSubstrate/DynamicLibraries/\x01ButNobodyCame.plist");
			unlink("/Library/MobileSubstrate/DynamicLibraries/\x01ButNobodyCame.dylib");
			unlink("/Library/MobileSubstrate/DynamicLibraries/ButNobodyCame.plist");
			unlink("/Library/MobileSubstrate/DynamicLibraries/ButNobodyCame.dylib");
			unlink("/usr/local/bin/bnchelper");

			break;
		case RootCommandTestAvailability: {
			BOOL available = (!getuid() && !geteuid() && !getgid());
			if (available) return RET_BNC_AVAILABLE;
			else return RET_BNC_ERROR;
			break;
		}
	}
	int status;
	if (!posix_spawnp(
		&pid, (char *)proc_argv[0],
		NULL, NULL, (char * const *)proc_argv,
		(char * const *)proc_envp
	)) waitpid(pid, &status, 0);
	else return RET_BNC_ERROR;
	if (WIFEXITED(status)) return WEXITSTATUS(status);
	else return RET_BNC_ERROR;
}
