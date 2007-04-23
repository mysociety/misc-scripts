#!/usr/bin/perl
#
# SMTP.pm:
# Test SMTP availability.
# 
# Really we should do a full test, sending a mail and ensuring that it
# arrives, but for the moment ignore that.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: SMTP.pm,v 1.3 2007-04-23 08:38:52 francis Exp $
#

package SMTP;

use strict;

use POSIX qw(EINPROGRESS EALREADY);
use Net::SMTP;

sub test () {
    my $smtp = new Net::SMTP('localhost', Timeout => 5);
    if (!$smtp) {
        # XXX Sometimes get "Operation now in progress" on water/whisky, not
        # sure why. Maybe a timing thing on quiet servers. Anyway, we don't
        # care.
        if ($! != EINPROGRESS && $! != EALREADY) {
            print "unable to connect to local SMTP server: $!\n";
            return;
        }
    }
}

1;
