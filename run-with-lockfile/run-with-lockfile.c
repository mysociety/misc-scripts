/*
 * run-with-lockfile.c:
 * Lock a file and then execute a program.
 *
 * Licenced under the GPL, version 2 or any later version.
 * 
 * Copyright (c) 2003 Chris Lightfoot. All rights reserved.
 * Email: chris@ex-parrot.com; WWW: http://www.ex-parrot.com/~chris/
 *
 */

static const char rcsid[] = "$Id: run-with-lockfile.c,v 1.2 2013-03-04 09:33:23 ian Exp $";

#include <sys/types.h>
#include <sys/wait.h>

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/stat.h>

#define SHELL_PATH "/bin/sh"
#define SHELL_NAME "sh"
#define WAIT_AFTER_TERM 10  /* seconds to wait after SIGTERM sent */

const char *opts="hnet:";
pid_t pid;
int timeout = 0;
char *command;

void usage(FILE *fp) {
    fprintf(fp,
"run-with-lockfile [-ne] [-t timeout] FILE COMMAND\n"
"\n"
"Open (perhaps create) and fcntl-lock FILE, then run COMMAND. If option -n\n"
"is given, fail immediately if the lock is held by another process;\n"
"otherwise, wait for the lock. When COMMAND is run, the variable LOCKFILE\n"
"will be set to FILE in its environment. If -e is given, execute the command\n"
"directly; otherwise COMMAND is run by passing it to /bin/sh with the -c\n"
"parameter.  The full path of the command should be given when -e is used.\n"
"\n"
"Exit value is that returned from COMMAND; or, if -n is given and the lock\n"
"could not be obtained, 100; or, if another error occurs, 101.\n"
"\n"
"If a timeout value is given with -t, the command will be killed if it runs\n"
"for longer than that number of seconds, and the exit value will be 102.\n"
"Note that, for the timeout to be effective, -e should also be used.\n"
"\n"
"Copyright (c) 2003-4 Chris Lightfoot, Mythic Beasts Ltd.\n"
"%s\n",
        rcsid
        );
}

void alarm_handler_kill(int sig) {
    fprintf(stderr, "run-with-lockfile: timed out; sending KILL to pid %d\n", pid);
    kill(pid, SIGKILL);
    exit(102);
}

void alarm_handler(int sig) {
    int n;
    struct sigaction si;

    alarm(0);
    if(pid <= 0)
        fprintf(stderr, "run-with-lockfile: timeout, but not killing pid %d!\n", pid);
    else {
        fprintf(stderr, "run-with-lockfile: %s timed out after %ds; sending TERM to pid %d and waiting for it to die...\n", command, timeout, pid);
        kill(pid, SIGTERM);

        si.sa_handler = alarm_handler_kill;
        sigemptyset(&si.sa_mask);
        si.sa_flags = 0;
        sigaction(SIGALRM, &si, NULL);

        alarm(WAIT_AFTER_TERM);

        waitpid(pid, &n, 0);

        /* If we get this far, the process exited */
        alarm(0);
        fprintf(stderr, "run-with-lockfile: pid %d died with status %d\n", pid, n);
    }
    exit(102);
}

int main(int argc, char *argv[]) {
    extern char *optarg;
    extern int optind;
    char opt, *file, *envvar;
    int wait = 1, call_exec = 0, n;
    int fd;
    struct stat st;
    struct flock fl;
    struct sigaction si;

    while ((opt = getopt(argc, argv, opts))!=-1) {
        switch (opt) {
            case 'h':
                usage(stdout);
                return 0;
                break;
            case 'n':
                wait = 0;
                break;
            case 'e':
                call_exec = 1;
                break;
            case 't':
                timeout = atoi(optarg);
                break;
            default:
                usage(stdout);
                return 101;
        }
    }

    if ((call_exec && argc - optind < 2) || (!call_exec && argc - optind != 2)) {
        fprintf(stderr, "run-with-lockfile: incorrect arguments\n");
        usage(stderr);
        return 101;
    }
    
    file    = argv[optind];
    command = argv[optind+1];

    if (-1 == (fd = open(file, O_RDWR | O_CREAT, 0666))) {
        fprintf(stderr, "run-with-lockfile: %s: %s\n", file, strerror(errno));
        return 101;
    }

    /* Paranoia. */
    if (-1 == fstat(fd, &st)) {
        fprintf(stderr, "run-with-lockfile: %s: %s\n", file, strerror(errno));
        return 101;
    } else if (!S_ISREG(st.st_mode)) {
        fprintf(stderr, "run-with-lockfile: %s: is not a regular file\n", file);
        return 101;
    }

    fl.l_type   = F_WRLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start  = 0;
    fl.l_len    = 0;

    while (-1 == (n = fcntl(fd, wait ? F_SETLKW : F_SETLK, &fl)) && errno == EINTR);

    if (n == -1) {
        if (!wait && (errno == EAGAIN || errno == EACCES))
            return 100;
        else {
            fprintf(stderr, "run-with-lockfile: %s: set lock: %s\n", file, strerror(errno));
            return 101;
        }
    }

    /* Set an environment variable. */
    envvar = malloc(strlen(file) + sizeof("LOCKFILE="));
    sprintf(envvar, "LOCKFILE=%s", file);
    putenv(envvar);
        
    if ((pid = fork()) == 0) {
        if (call_exec) {
            if (execv(command, &argv[optind+1]) < 0) {
                fprintf(stderr, "run-with-lockfile: %s: %s\n", command, strerror(errno));
                n = 101;
            }
        } else if (execl(SHELL_PATH, SHELL_NAME, "-c", command, NULL) < 0) {
            if (n == -1) {
                fprintf(stderr, "run-with-lockfile: %s: %s\n", command, strerror(errno));
                n = 101;
            } else if (n == 127 && errno != 0) {
                fprintf(stderr, "run-with-lockfile: /bin/sh: %s\n", strerror(errno));
                n = 101;
            }
        }
    } else if(pid < 0) {
        fprintf(stderr, "run-with-lockfile: fork failed: %s\n", strerror(errno));
        n = 101;
    } else {
        /* Set an alarm (if -t wasn't specified, timeout will be zero
           which disables the alarm anyway).  SA_NODEFER ensures that another
           alarm can be set in the signal handler. */
        si.sa_handler = alarm_handler;
        sigemptyset(&si.sa_mask);
        si.sa_flags = SA_NODEFER;
        sigaction(SIGALRM, &si, NULL);

        alarm(timeout);

        if (waitpid(pid, &n, 0) != pid) {
            fprintf(stderr, "run-with-lockfile: waitpid failed: %s\n", strerror(errno));
            n = 101;
        }
        alarm(0);
    }

    close(fd);

    return n;
}
