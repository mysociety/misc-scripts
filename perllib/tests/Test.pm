#!/usr/bin/perl
#
# Test.pm:
# Used to test the monitoring script. Fails if file
# /etc/mysociety/monitoring-test exists.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Test.pm,v 1.1 2006-04-04 12:43:00 francis Exp $
#

package Test;

use strict;

sub test () {
    if (-e '/etc/mysociety/monitoring-test') {
        print "File /etc/mysociety/monitoring-test exists\n";
    }
}

1;
