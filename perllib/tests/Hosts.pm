#!/usr/bin/perl
#
# Hosts.pm:
# Test hosts are up using ping.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Hosts.pm,v 1.22 2012-06-28 12:52:56 louise Exp $
#

package Hosts;

use strict;

use Net::Ping;

my @hostlist = qw(
        arrow.ukcod.org.uk
        dart.ukcod.org.uk
        eclipse.ukcod.org.uk
        majestic.ukcod.org.uk
        phoenix.ukcod.org.uk
        rocket.ukcod.org.uk
        samson.ukcod.org.uk
        vulcan.ukcod.org.uk
        wildfire.ukcod.org.uk
    );


use constant NPINGS => 10;

sub email() { return 'serious'; }

sub test () {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');

    my $P = new Net::Ping('icmp', 1);
    foreach my $hostname (@hostlist) {
        my $i;
        for ($i = 0; $i < NPINGS; ++$i) {
            last if ($P->ping($hostname));
        }
        print "$hostname: received no response from after $i pings sent\n"
            if ($i == NPINGS);
    }
}

1;
