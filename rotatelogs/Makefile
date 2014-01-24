#
# Makefile:
# Build rotatelogs.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.3 2006-09-13 19:35:39 chris Exp $
#

SENDMAIL_BIN = /usr/sbin/sendmail

CFLAGS = -Wall -g -I/usr/include/pcre '-DSENDMAIL_BIN="$(SENDMAIL_BIN)"'
LDFLAGS =
LDLIBS = -lpcre

rotatelogs: rotatelogs.c
	$(CC) $(CFLAGS) rotatelogs.c $(LDFLAGS) $(LDLIBS) -o rotatelogs

clean:
	rm -f rotatelogs *~ core
