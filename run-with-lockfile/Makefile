#
# Makefile:
# Build run-with-lockfile.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.2 2006-02-16 12:34:37 chris Exp $
#

CFLAGS = -Wall -g 
LDFLAGS =
LDLIBS = 

run-with-lockfile: run-with-lockfile.c
	$(CC) $(CFLAGS) run-with-lockfile.c $(LFGLAGS) $(LDLIBS) -o run-with-lockfile

clean:
	rm -f rotatelogs *~ core
