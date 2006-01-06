#
# Makefile:
# Build rotatelogs.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.2 2006-01-06 09:59:17 maint Exp $
#

SENDMAIL_BIN = /usr/sbin/sendmail

CFLAGS = -Wall -g -I/usr/include/pcre '-DSENDMAIL_BIN="$(SENDMAIL_BIN)"'
LDFLAGS =
LDLIBS = -lpcre

rotatelogs: rotatelogs.c
	$(CC) $(CFLAGS) rotatelogs.c $(LFGLAGS) $(LDLIBS) -o rotatelogs

clean:
	rm -f rotatelogs *~ core
