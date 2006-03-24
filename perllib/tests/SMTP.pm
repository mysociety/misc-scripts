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
# $Id: SMTP.pm,v 1.2 2006-03-24 21:21:07 chris Exp $
#

package SMTP;

use strict;

use Net::SMTP;

sub test () {
    my $smtp = new Net::SMTP('localhost', Timeout => 5);
    if (!$smtp) {
        print "unable to connect to local SMTP server: $!\n";
        return;
    }
}

1;
