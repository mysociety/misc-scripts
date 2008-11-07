#!/usr/bin/perl
#
# Hosts.pm:
# Test hosts are up using ping.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Hosts.pm,v 1.8 2008-11-07 17:26:10 root Exp $
#

package Hosts;

use strict;

use Net::Ping;

my @hostlist = qw(
        sponge.ukcod.org.uk

        bitter.ukcod.org.uk
        tea.ukcod.org.uk
        balti.ukcod.org.uk

        steak.ukcod.org.uk

        water.ukcod.org.uk

        sandwich.ukcod.org.uk
        pudding.ukcod.org.uk
        cake.ukcod.org.uk
    );
#peas.ukcod.org.uk
#whisky.ukcod.org.uk


use constant NPINGS => 10;

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
