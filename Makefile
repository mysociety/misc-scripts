#
# Makefile:
# Build rotatelogs.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.1 2005-11-18 10:07:21 chris Exp $
#

SENDMAIL_BIN = /usr/libexec/sendmail

CFLAGS = -Wall -g -I/usr/include/pcre '-DSENDMAIL_BIN="$(SENDMAIL_BIN)"'
LDFLAGS =
LDLIBS = -lpcre

rotatelogs: rotatelogs.c
	$(CC) $(CFLAGS) rotatelogs.c $(LFGLAGS) $(LDLIBS) -o rotatelogs

clean:
	rm -f rotatelogs *~ core
