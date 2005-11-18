/*
 * rotatelogs.c:
 * Rotate logs, and optionally email error messages to somebody.
 *
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: rotatelogs.c,v 1.1 2005-11-18 10:07:21 chris Exp $";

#include <sys/types.h>

#include <ctype.h>
#include <errno.h>
#include <pcre.h>
#include <signal.h>
#include <stdarg.h>
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
"Usage: rotatelogs -h | [-l] [-f FORMAT] [-e ADDRESS] [-r RULES] NAME INTERVAL\n"
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
"If -l is specified, then whenever a new logfile is opened, a symlink will be\n"
"created from NAME to it.\n"
"\n"
"If -e is specified, then log lines will be emailed to the specified ADDRESS.\n"
"If -r is specified, it should give the name of a file of RULES which will be\n"
"used to filter log lines to be written to the log and/or emailed. Each line\n"
"in the file should be blank, a comment introduced by '#', or consist of a\n"
"keyword followed by whitespace and a regular expression in the format of\n"
"PCRE. Valid keywords are,\n"
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
    r->r_next = NULL;
    
    while ((line = getline(fp, &l))) {
        char *keyword, *regex;
        struct rule R, *pR;
        const char *err;
        int erroff;

        ++linenum;

        /* Remove any terminating \n. */
        if (l > 0 && line[l - 1] == '\n') line[l - 1] = 0;
        /* Skip blank/comment lines. */
        if (!line[strspn(line, " \t")] || *line == '#') continue;

        keyword = line + strspn(line, " \t");
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

/* reopen_logfile FD INTERVAL NAME FORMAT TIME SYMLINK
 * */
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

    if (-1 == (newfd = open(buf, O_WRONLY | O_CREAT | O_APPEND | O_SYNC, 0644))) {
        our_error("%s: open: %s", buf, strerror(errno));
        return fd;
    }

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
        } else if (-1 == rename(buf2, name)) {
            our_error("%s: rename to %s: %s", buf2, name, strerror(errno));
            unlink(buf2);
        }
    }

    return newfd;
}

/* reread_rules RULES FILENAME ST
 * */
struct rule *reread_rules(struct rule *rules, const char *filename, struct stat *st) {
    struct stat st2;
    struct rule *r;

    if (-1 == stat(filename, &st2)) {
        if (errno != ENOENT)
            our_error("%s: stat: %s\n", filename, strerror(errno));
        return rules;
    }

    if (st->st_size == st2.st_size
        && st->st_mtime == st2.st_mtime
        && st->st_ino == st2.st_ino)
        return rules;

    *st = st2;

    r = rules_read(filename);
    if (r) {
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
                   else fprintf(fp, "\\%02x", (unsigned int)*p);
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
            "Subject: error logged to %s\n"
            "To: %s\n"
            "\n",
            name, addr);

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

/* main ARGC ARGV
 * Entry point. */
int main(int argc, char *argv[]) {
    const char *optstr = "+hlf:e:r:";
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
    struct stat st = {0};   /* for rules file */
    struct rule *r = NULL;
    int email_fd = -1;      /* pipe to email-sending subprocess */

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

            case 'r':
                rules = optarg;
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
    if (rules) r = reread_rules(r, rules, &st);
    while ((line = getline(stdin, &linelen))) {
        enum action a;
        if (rules) {
            /* Ugh. getline returns a static buffer. */
            static char *buf;
            static size_t buflen;
            if (!buf || buflen < linelen + 1) buf = realloc(buf, buflen = (linelen + 1) * 2);
            memcpy(buf, line, linelen + 1);
            line = buf;
            r = reread_rules(r, rules, &st);
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

                /* Now open a new one. */
                if (email_fd == -1) {
                    int pp[2];
                    if (-1 == pipe(pp))
                        our_error("pipe: %s", strerror(errno));
                    else {
                        email_fd = pp[1];
                        fcntl(email_fd, F_SETFL, fcntl(email_fd, F_GETFL) | O_NONBLOCK);
                        do_email(name, email, line, linelen, pp[0]);
                        close(pp[0]); /* in this process */
                    }
                }
            }
        }
    }

    return 0;
}

