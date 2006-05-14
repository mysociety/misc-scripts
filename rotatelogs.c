/*
 * rotatelogs.c:
 * Rotate logs, and optionally email error messages to somebody.
 *
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: rotatelogs.c,v 1.8 2006-05-14 14:00:31 chris Exp $";

#include <sys/types.h>

#include <ctype.h>
#include <errno.h>
#include <grp.h>
#include <pcre.h>
#include <pwd.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <regex.h>
#include <unistd.h>

#include <sys/fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>

int logfile_fd = -1;

/* our_error FORMAT ...
 * Log a printf-style message to the logfile, or standard error if the logfile
 * is not open. */
void our_error(const char *fmt, ...) {
    va_list ap;
    int fd, n;
    char buf[4096];
    
    fd = logfile_fd == -1 ? 2 : logfile_fd;

    va_start(ap, fmt);
    n = vsnprintf(buf, (sizeof buf) - 2, fmt, ap);
    buf[n++] = '\n';

    if (fd == 2) write(2, "rotatelogs: ", 12);
    /* XXX write apache-style timestamp to log? */
    write(fd, buf, n);
}

/* getline STREAM LEN
 * Read a line from STREAM. Returns a whole line ending '\n'; or, in case of
 * error or EOF after reading at least one character, a partial line ending
 * without a '\n'; or NULL. If LEN is not NULL, *LEN is set to the length of
 * the whole line returned. */
static unsigned char *getline(FILE *fp, size_t *len) {
    static unsigned char *buf;
    static size_t buflen;
    size_t i;
    int c;
    if (!buf) buf = malloc(buflen = 1024);
    if (!len) len = &i;
    *len = 0;
    while (EOF != (c = fgetc(fp))) {
        if ((*len + 1) >= buflen) buf = realloc(buf, buflen *= 2);
        buf[(*len)++] = (unsigned char)c;
        if (c == '\n') break;
    }
    buf[*len] = 0;  /* NUL-terminate, though the buffer may contain NULs */
    if (*len == 0)
        return NULL;
    else
        return buf;
}

/* usage STREAM
 * Print a usage message to STREAM. */
void usage(FILE *fp) {
    fprintf(fp,
"rotatelogs (mySociety version) - rotate log files; optionally, exclude\n"
"        certain lines from the logs; optionally, send logged messages by\n"
"        email\n"
"\n"
"Usage: rotatelogs -h | [OPTIONS] NAME INTERVAL\n"
"\n"
"Write log lines to automatically-rotated files. The current logfile is rotated\n"
"every INTERVAL, which should be either 0, in which case no log rotation will be\n"
"done, or specified in the form NUMBER [UNIT].  UNIT may be 'seconds' (the\n"
"default), 'minutes', 'days', 'weeks', or any unambiguous abbreviation. The\n"
"filename to which lines are written is formed from NAME and a suffix, which is\n"
"by default '.' followed by the number of seconds since the epoch;\n"
"alternatively, a strftime(3) FORMAT may be given, which will be used to\n"
"generate the appropriate format.\n"
"\n"
"A new file is created at each multiple of INTERVAL in epoch time.\n"
"\n"
"Options:\n"
"\n"
"    -l          When a new logfile is created, make a symlink to it from NAME\n"
"\n"
"    -f FORMAT   Use the strftime(3) FORMAT for the suffix on logfile names,\n"
"                rather than '.' followed by the number of seconds since the\n"
"                epoch.\n"
"\n"
"    -e ADDRESS  Emailed logged lines to ADDRESS.\n"
"\n"
"    -i INTERVAL Send emails to ADDRESS no more than once every INTERVAL.\n"
"                This limit is applied only for a single rotatelogs process;\n"
"                the default is 30 minutes.\n"
"\n"
"    -r RULES    Read the given file of RULES and use them to filter lines to\n"
"                be written to the log and/or emailed.\n"
"\n"
"    -m MODE     Use the octal MODE for creating new log files, rather than\n"
"                the default, 0640.\n"
"\n"
"    -o OWNER    Create log files owned by OWNER rather than the UID and GID\n"
"                of the rotatelogs process. OWNER may be specified as USER,\n"
"                USER:GROUP, or :GROUP. This will only work if the\n"
"                rotatelogs process has sufficient privilege to change the\n"
"                file ownership as required.\n"
"\n"
"If -r is specified, it should give the name of a file of RULES which will be\n"
"used to filter log lines to be written to the log and/or emailed. Each line\n"
"in the file should be blank, a comment introduced by '#', the word 'include'\n"
"followed by whitespace and the name of another file of rules to be processed\n"
"as if they were inserted into the current file at the include statement, or\n"
"consist of one of the following keywords, followed by whitespace and a\n"
"regular expression in the format of PCRE:\n"
"\n"
"    pass    Pass the log line through to the output file, and to any email\n"
"            contact.\n"
"\n"
"    passnoemail\n"
"            Pass the log line through to the output file, but do not trigger\n"
"            any sending of email.\n"
"\n"
"    drop    Discard the log line entirely.\n"
"\n"
"When a line matches several rules, the last one takes effect. Rules files are\n"
"treated as beginning with an implicit 'pass .*'\n"
"\n"
"This program is designed as a replacement to the rotatelogs program\n"
"distributed with apache, and may be used in the same way.\n"
"\n"
"Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.\n"
"Email: chris@mysociety.org; WWW: http://www.mysociety.org/\n"
"%s\n",
            rcsid);
}

enum action { act_pass = 0, act_passnoemail, act_drop, act_max };
const char *straction[] = {"pass", "passnoemail", "drop"};

/* struct rule
 * Regex-based rule for logfile filtering. */
struct rule {
    enum action r_action;
    char *r_regex;
    pcre *r_pcre;
    pcre_extra *r_pcre_extra;
    /* record the file from which the rules came, and its attributes, so we
     * know when to re-read them. */
    char *r_filename;
    struct stat r_st;
    struct rule *r_next;
};

void rules_free(struct rule *r);

/* rules_read FILENAME
 * Read rules from FILENAME, returning a linked list of struct rule on success
 * or NULL on failure. The list is in reverse order, so that the first element
 * of the linked list is the last rule in the file. */
struct rule *rules_read(const char *filename) {
    FILE *fp;
    struct rule *r;
    char *line;
    size_t l;
    int linenum = 0;

    if (!(fp = fopen(filename, "rt"))) {
        our_error("%s: open: %s", filename, strerror(errno));
        return NULL;
    }

    /* Always construct at least one rule, so that an empty rules file may be
     * distinguished from a read error. */
    r = malloc(sizeof *r);
    r->r_action = act_pass;
    r->r_regex = strdup("(none)");
    r->r_pcre = NULL;
    r->r_pcre_extra = NULL;
    r->r_filename = strdup(filename);
    fstat(fileno(fp), &r->r_st);    /* XXX we assume this succeeds */
    r->r_next = NULL;
    
    while ((line = getline(fp, &l))) {
        char *keyword, *regex;
        struct rule R = {0}, *pR;
        const char *err;
        int erroff;

        ++linenum;

        /* Remove any terminating \n. */
        if (l > 0 && line[l - 1] == '\n') line[l - 1] = 0;
        /* Skip blank/comment lines. */
        if (!line[strspn(line, " \t")] || *line == '#') continue;

        keyword = line + strspn(line, " \t");

        /* Process an include file. */
        if (0 == strncmp(keyword, "include", 7) && strchr(" \t", keyword[7])) {
            /* XXX we ought to test for an include loop */
            char *f;
            struct rule *r2, *p;
            f = keyword + 7;
            f += strspn(f, " \t");
            if (!*filename) {
                our_error("%s:%d: missing filename after include", filename, linenum);
                continue;
            }
            r2 = rules_read(f);
            if (!r2) {
                our_error("%s:%d: error reading included %s", filename, linenum, f);
                continue;
            }
            /* Find end of new rules. */
            for (p = r2; p->r_next; p = p->r_next);
            p->r_next = r;
            r = r2;
            continue;
        }
        
        for (R.r_action = 0; R.r_action < act_max; ++R.r_action) {
            size_t n;
            n = strlen(straction[R.r_action]);
            if (0 == strncmp(keyword, straction[R.r_action], n)
                && strchr(" \t", keyword[n])) {
                regex = keyword + n;
                regex += strspn(regex, " \t");
                break;
            }
        }

        if (R.r_action == act_max) {
            our_error("%s:%d: syntax error (bad keyword); ignoring rule", filename, linenum);
            continue;
        }

        if (!(R.r_pcre = pcre_compile(regex, 0, &err, &erroff, NULL))) {
            our_error("%s:%d: error in regex: %s (near '%.5s', char %d); ignoring rule", filename, linenum, err, regex + erroff, 1 + erroff);
            continue;
        }

        err = NULL;
        R.r_pcre_extra = pcre_study(R.r_pcre, 0, &err);
        if (err) {
            our_error("%s:%d: error studying regex: %s; ignoring rule", filename, linenum, err);
            pcre_free(R.r_pcre);
            continue;
        }

        /* Success. */
        R.r_regex = strdup(regex);
        pR = malloc(sizeof *pR);
        *pR = R;
        pR->r_next = r;
        r = pR;
    }

    if (ferror(fp)) {
        our_error("%s:%d: %s", filename, linenum, strerror(errno));
        rules_free(r);
        r = NULL;
    }

    fclose(fp);

    return r;
}

/* rules_free RULES
 * Free a linked list of RULES. */
void rules_free(struct rule *r) {
    struct rule *rn;
    while (r) {
        rn = r->r_next;
        free(r->r_regex);
        if (r->r_pcre) pcre_free(r->r_pcre);
        if (r->r_pcre_extra) pcre_free(r->r_pcre_extra);
        if (r->r_filename) free(r->r_filename);
        free(r);
        r = rn;
    }
}

/* rules_test RULES LINE LEN
 * Test the LEN-byte log LINE against the RULES, returning the resulting
 * action. */
enum action rules_test(struct rule *r, const char *line, const size_t len) {
    struct rule *p;
    for (p = r; p; p = p->r_next) {
        int rc;
        if (!p->r_pcre)
            return p->r_action;
        rc = pcre_exec(p->r_pcre, p->r_pcre_extra, line, (int)len, 0, 0, NULL, 0);
        if (rc == 0)
            return p->r_action;
        else if (rc != PCRE_ERROR_NOMATCH)
            our_error("pcre_exec(/%s/, ...) returned error value %d", p->r_regex, rc);
    }
    return act_pass;
}

/* parse_interval STRING
 * Interpret STRING, which matches /^\s*\d+\s*[mhdw]/, as an interval. Returns
 * the number of seconds in the interval on success, or 0 on failure. */
time_t parse_interval(const char *s) {
    const char *p;
    time_t a;
    p = s + strspn(s, " \t");
    if (!isdigit(*p))
        return 0;
    a = (time_t)atoi(p);
    p += strspn(p, "0123456789");
    p += strspn(p, " \t");
    if (*p) {
        switch (tolower(*p)) {
            case 'w':
                a *= 7 * 24 * 3600;
                break;

            case 'd':
                a *= 24 * 3600;
                break;

            case 'h':
                a *= 3600;
                break;

            case 'm':
                a *= 60;
                break;

            case 's':
                break;
    
            default:
                a = 0;
                break;
        }
    } else 
        a *= 1; /* assume seconds */
    
    return a;
}

static int logfile_mode = 0640;
static uid_t logfile_uid = -1;
static gid_t logfile_gid = -1;

/* reopen_logfile FD INTERVAL NAME FORMAT TIME SYMLINK
 * If the logfile open on FD should now be reopened under a new name because
 * INTERVAL has passed, do so, using FORMAT as an argument to strftime to
 * obtain a suffix added to NAME. If SYMLINK is true, create a symlink from
 * NAME itself to the new file. Returns a file descriptor open on the new
 * logfile, FD if no new logfile is needed, or -1 on error. */
int reopen_logfile(int fd, const time_t interval, const char *name, const char *format, time_t *t, const int make_symlink) {
    time_t now;
    struct tm T;
    static char *buf, *buf2;
    static size_t buflen;
    int newfd;
#define MAXTIMELEN 256
    if (!buf) {
        buf = malloc(buflen = strlen(name) + MAXTIMELEN + 1);
        buf2 = malloc(strlen(name) + 64);
    }

    time(&now);
    now -= now % interval;
    /* Is the current logfile still valid? */
    if (now == *t && fd != -1)
        return fd;

    localtime_r(&now, &T);
    strcpy(buf, name);
    strftime(buf + strlen(name), MAXTIMELEN, format, &T);

    if (-1 == (newfd = open(buf, O_WRONLY | O_CREAT | O_APPEND | O_SYNC, logfile_mode))) {
        our_error("%s: open: %s", buf, strerror(errno));
        return fd;
    }
    
    /* Set the ownership of the new file. Note that there's a race here, but
     * it's not very important. */
    if ((-1 != logfile_uid || -1 != logfile_gid)
        && -1 == fchown(newfd, logfile_uid, logfile_gid))
        /* This is not a fatal error; report it, but do not abort. */
        our_error("%s: fchown(%d, %d): %s", buf, logfile_uid, logfile_gid, strerror(errno));

    *t = now;

    if (make_symlink) {
        /* We must construct a relative symlink, because we are not evil. */
        char *basename;
        basename = strrchr(buf, '/');
        if (basename) basename++;
        else basename = buf;

        /* symlink(2) cannot be used to overwrite an existing file, so we must
         * create a symlink under a new name and rename it over the old one. */
again:
        sprintf(buf2, "%s.%d.%d.%d", name, (int)getpid(), (int)time(NULL), rand());
        if (-1 == symlink(basename, buf2)) {
            if (errno == EEXIST)
                goto again;
            else
                our_error("%s: symlink to %s: %s", buf2, basename, strerror(errno));
        }
        
        /* We should also set the ownership of the symlink. */
        if ((-1 != logfile_uid || -1 != logfile_gid)
            && -1 == lchown(buf2, logfile_uid, logfile_gid))
            /* Again, not a fatal error. */
            our_error("%s: lchown(%d, %d): %s", buf2, logfile_uid, logfile_gid, strerror(errno));
        
        if (-1 == rename(buf2, name)) {
            our_error("%s: rename to %s: %s", buf2, name, strerror(errno));
            unlink(buf2);
        }
    }

    return newfd;
}

/* reread_rules RULES FILENAME
 * If RULES is NULL, or if any of the files from which the rules were read have
 * changed, then read FILENAME and return the new set of rules; otherwise,
 * return RULES. */
struct rule *reread_rules(struct rule *rules, const char *filename) {
    struct rule *r;
    bool doread = 0;

    if (!rules)
        doread = 1;
    else {
        for (r = rules; r; r = r->r_next) {
            struct stat st;
            if (!r->r_filename)
                continue;
            if (-1 == stat(r->r_filename, &st)
                || st.st_size != r->r_st.st_size
                || st.st_mtime != r->r_st.st_mtime
                || st.st_ino != r->r_st.st_ino) {
                doread = 1;
                break;
            }
        }
    }

    if (doread && (r = rules_read(filename))) {
        rules_free(rules);
        rules = r;
    }

    return rules;
}

#ifndef SENDMAIL_BIN
#   define SENDMAIL_BIN    "/usr/sbin/sendmail"
#endif /* SENDMAIL_BIN */

/* EMAIL_TIMEOUT
 * Number of seconds we wait, collecting subsequent log lines, before sending
 * an email about a log line. */
#define EMAIL_TIMEOUT 5

/* EMAIL_INTERVAL
 * Default minimum interval between sending two emails, in seconds. */
#define EMAIL_INTERVAL 1800

/* escaped_write_lines STREAM LINES LEN
 * Write the LEN-byte log LINES to STREAM, escaping non-ASCII characters */
void escaped_write_lines(FILE *fp, const char *line, const size_t len) {
    const char *p;
    for (p = line; p < line + len; ++p) {
        switch (*p) {
            case '\n': fprintf(fp, "\n"); break;
            case '\t': fprintf(fp, "\\t"); break;
            case '\r': fprintf(fp, "\\r"); break;
            default:
                   if (isprint(*p)) fputc(*p, fp);
                   else fprintf(fp, "\\x%02x", (unsigned int)*p);
                   break;
        }
    }
}

/* do_email NAME ADDRESS LINE LEN FD
 * Send an email to ADDRESS, consisting of the LEN-byte log LINE, and possibly
 * some further lines read from FD. Returns 0 on success, or -1 on failure. */
int do_email(const char *name, const char *addr, const char *line, const size_t len, int fd) {
    pid_t p;
    int pp[2];
    FILE *sendmail;
    char *s_argv[] = { SENDMAIL_BIN, NULL, NULL },
         *s_envp[] = { "PATH=/bin", NULL };
    time_t now, t;
    char buf[1024];
    static char hostname[64];

    if (!*hostname) {
        gethostname(hostname, sizeof hostname);
        hostname[(sizeof hostname) - 1] = 0;
    }

    time(&now);

    p = fork();
    if (p == -1) {
        our_error("fork: %s", strerror(errno));
        return -1;
    } else if (p > 0) {
        /* Parent. Wait and return. */
        waitpid(p, NULL, 0);
        return 0;   /* XXX test exit status */
    }
    /* Child. Fork again. */
    p = fork();
    if (p != 0)
        _exit(p == -1);
    /* Child #2. */
    s_argv[1] = (char*)addr;
    if (-1 == pipe(pp) || -1 == (p = fork()))
        _exit(1);
    if (p == 0) {
        /* Exec sendmail. */
        int i;
        for (i = 0; i < 3; ++i) close(i);
        close(pp[1]);
        dup(pp[0]); /* stdin */
        dup(open("/dev/null", O_WRONLY)); /* stdout/stderr */
        execve(s_argv[0], s_argv, s_envp);
        _exit(1);
    }
    if (!(sendmail = fdopen(pp[1], "w")))
        _exit(1);
    fprintf(sendmail,
            "Subject: error logged to %s on %s\n"
            "To: %s\n"
            "\n",
            name, hostname, addr);

    /* Need to be a bit more careful with the logged error line itself. */
    escaped_write_lines(sendmail, line, len);

    /* Yuk. Now we want to (potentially) collect a few lines of context. So we
     * read lines from the pipe for up to EMAIL_TIMEOUT seconds. */
    fcntl(fd, F_SETFL, fcntl(fd, F_SETFL) | O_NONBLOCK);
    while (time(&t) < now + EMAIL_TIMEOUT) {
        ssize_t n;
        if (t < now)
            break; /* time has gone backwards, so bail */
        n = read(fd, buf, sizeof buf);
        if (n == -1) {
            if (errno != EAGAIN)
                break;
            else
                sleep(1);   /* XXX should use select, but this is good enough */
        } else if (n > 0)
            escaped_write_lines(sendmail, buf, n);
        else
            break;
    }
    close(fd);
    fclose(sendmail);

    _exit(0);
}

/* parse_owner OWNER
 * Set logfile_uid and logfile_gid from OWNER, which should be of the form
 * "USER", "USER:GROUP" or ":GROUP". Returns nonzero on success or prints an
 * error and returns zero on failure. */
static bool parse_owner(const char *s) {
    char *user, *group;
    bool ret = 0;
    
    user = strdup(s);
    group = strchr(user, ':');
    if (group) *(group++) = 0;

    if (user[strspn(user, "0123456789")]) {
        struct passwd *p;
        if ((p = getpwnam(user)))
            logfile_uid = p->pw_uid;
        else {
            fprintf(stderr, "rotatelogs: no such user '%s'\n", user);
            goto fail;
        }
    } else if (*user)
        logfile_uid = (uid_t)atoi(user);
    /* else user is blank, so only set group */

    if (group[strspn(group, "0123456789")]) {
        struct group *g;
        if ((g = getgrnam(group)))
            logfile_gid = g->gr_gid;
        else {
            fprintf(stderr, "rotatelogs: no such group '%s'\n", group);
            goto fail;
        }
    } else if (*group)
        logfile_gid = (gid_t)atoi(group);
    /* else blank group */

    ret = 1;

fail:
    free(user);
    return ret;
}

/* main ARGC ARGV
 * Entry point. */
int main(int argc, char *argv[]) {
    const char *optstr = "+hlf:e:i:r:m:o:";
    extern char *optarg;
    extern int opterr, optopt, optind;
    int c;
    char *name = NULL;
    time_t interval, ft;
    int make_symlink = 0;
    char *format = ".%s";   /* NB GNU extension */
    char *email = NULL;
    char *rules = NULL;
    char *line;
    size_t linelen;
    struct rule *r = NULL;
    int email_fd = -1;      /* pipe to email-sending subprocess */
    int email_interval = EMAIL_INTERVAL;
    time_t last_email = 0;

    signal(SIGPIPE, SIG_IGN);
    
    opterr = 0;

    while ((c = getopt(argc, argv, optstr)) != -1) {
        switch (c) {
            case 'h':
                usage(stdout);
                return 1;

            case 'l':
                make_symlink = 1;
                break;

            case 'f':
                format = optarg;
                break;

            case 'e':
                email = optarg; /* XXX syntax check */
                break;

            case 'i':
                if (!(email_interval = parse_interval(optarg))) {
                    fprintf(stderr, "rotatelogs: '%s' is not a valid interval\n", optarg);
                    return 1;
                }
                break;

            case 'r':
                rules = optarg;
                break;

            case 'm':
                if (strlen(optarg) > 4 || optarg[strspn(optarg, "01234567")]) {
                    fprintf(stderr, "rotatelogs: option -m should give a file mode in octal\n");
                    return 1;
                }
                sscanf(optarg, "%o", &logfile_mode);
                break;

            case 'o':
                if (!parse_owner(optarg))
                    return 1;
                break;

            case '?':
            default:
                if (strchr(optstr, optopt))
                    fprintf(stderr, "rotatelogs: option -%c requires an argument\n", optopt);
                else
                    fprintf(stderr, "rotatelogs: unknown option -%c\n", optopt);
                fprintf(stderr, "rotatelogs: try -h for help\n");
                return 1;
        }
    }

    if (argc - optind != 2) {
        fprintf(stderr, "rotatelogs: two non-option arguments required\n"
                        "rotatelogs: try -h for help\n");
        return 1;
    }

    name = argv[optind++];
    if (!(interval = parse_interval(argv[optind]))) {
        fprintf(stderr, "rotatelogs: '%s' is not a valid interval\n", argv[optind]);
        return 1;
    }

    time(&ft);
    logfile_fd = reopen_logfile(logfile_fd, interval, name, format, &ft, make_symlink);
    if (rules) r = reread_rules(r, rules);
    while ((line = getline(stdin, &linelen))) {
        enum action a;
        if (rules) {
            /* Ugh. getline returns a static buffer. */
            static char *buf;
            static size_t buflen;
            if (!buf || buflen < linelen + 1) buf = realloc(buf, buflen = (linelen + 1) * 2);
            memcpy(buf, line, linelen + 1);
            line = buf;
            r = reread_rules(r, rules);
        }
        a = rules_test(r, line, linelen);
        if (a != act_drop) {
            /* XXX consider adding timestamp if one is not present? */
            logfile_fd = reopen_logfile(logfile_fd, interval, name, format, &ft, make_symlink);
            if (line[linelen - 1] != '\n')
                line[linelen++] = '\n';
            write(logfile_fd, line, linelen);
                /* Not much we can do if this fails (e.g. because we're out of
                 * disk space). "Never test for an error condition you don't
                 * know how to handle." */

            if (a != act_passnoemail) {
                /* First try writing it to an existing mail subprocess. */
                if (email_fd != -1) {
                    ssize_t n;
                    n = write(email_fd, line, linelen);
                    if (n != linelen) {
                        /* Most likely EPIPE, but could be EAGAIN if the other
                         * end has blocked. */
                        close(email_fd);
                        email_fd = -1;
                        if (n > 0) line += n;
                    }
                }

                /* Now open a new one, assuming it's not too soon after we
                 * sent the last email. */
                if (email_fd == -1
                    && time(NULL) > last_email + email_interval) {
                    int pp[2];
                    if (-1 == pipe(pp))
                        our_error("pipe: %s", strerror(errno));
                    else {
                        email_fd = pp[1];
                        fcntl(email_fd, F_SETFL, fcntl(email_fd, F_GETFL) | O_NONBLOCK);
                        do_email(name, email, line, linelen, pp[0]);
                        close(pp[0]); /* in this process */
                        time(&last_email);
                    }
                }
            }
        }
    }

    rules_free(r); /* keep valgrind happy */

    return 0;
}

