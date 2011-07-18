#!/usr/bin/perl
#
# WDTK.pm:
# Tests for WhatDoTheyKnow.
#
# Nasty because we want to check each host for multihomed site.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: WDTK.pm,v 1.2 2011-07-18 18:05:59 robin Exp $
#

package WDTK;

use strict;
use Monitor;

use constant TIMEOUT => 30; # Wait up to 30 seconds for a response

my @pages = qw(
    http://www.whatdotheyknow.com/
    http://www.whatdotheyknow.com/request/regenda_group_hoaos
);

sub email() { return 'cron-whatdotheyknow'; }

sub test () {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');
    foreach my $page (@pages) {
        Monitor::test_web($page, TIMEOUT);
    }
}

1;
