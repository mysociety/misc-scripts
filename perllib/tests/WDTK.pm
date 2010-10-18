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
# $Id: WDTK.pm,v 1.1 2010-10-18 11:44:08 matthew Exp $
#

package WDTK;

use strict;
use Monitor;

my @pages = qw(
    http://www.whatdotheyknow.com/
    http://www.whatdotheyknow.com/request/regenda_group_hoaos
);

sub email() { return 'cron-whatdotheyknow'; }

sub test () {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');
    foreach my $page (@pages) {
        Monitor::test_web($page);
    }
}

1;
