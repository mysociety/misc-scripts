#!/usr/bin/perl
#
# Hosts.pm:
# Test hosts are up using ping.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Hosts.pm,v 1.2 2007-01-23 09:15:57 francis Exp $
#

package Hosts;

use strict;

use Net::Ping;

my @hostlist = qw(
        very.unfortu.net
        cake.ukcod.org.uk

        bitter.ukcod.org.uk
        tea.ukcod.org.uk
        balti.ukcod.org.uk

        peas.ukcod.org.uk
        steak.ukcod.org.uk

        whisky.ukcod.org.uk
        water.ukcod.org.uk

        cerulean.beasts.org
    );

use constant NPINGS => 10;

sub test () {
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
