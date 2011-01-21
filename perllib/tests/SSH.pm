#!/usr/bin/perl
#
# SSH.pm:
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: SSH.pm,v 1.18 2011-01-21 17:03:08 louise Exp $
#

package SSH;

use strict;

use IO::Socket;

my @hostlist = qw(
        sponge.ukcod.org.uk

        balti.ukcod.org.uk
        bitter.ukcod.org.uk
        tea.ukcod.org.uk

        steak.ukcod.org.uk

        water.ukcod.org.uk
        cake.ukcod.org.uk
        sandwich.ukcod.org.uk
        whisky.ukcod.org.uk
        peas.ukcod.org.uk

        stilton.ukcod.org.uk

        arrow.ukcod.org.uk
        comet.ukcod.org.uk
        fury.ukcod.org.uk
        majestic.ukcod.org.uk
        phoenix.ukcod.org.uk
        rocket.ukcod.org.uk
        samson.ukcod.org.uk
        vulcan.ukcod.org.uk
        wildfire.ukcod.org.uk
    );


sub email() { return 'sysadmin'; }

sub test () {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');

    foreach my $host (@hostlist) {
        my $s = new IO::Socket::INET(PeerHost => $host, PeerPort => 22);
        if (!$s) {
            print "$host: socket/connect: $!\n";
            next;
        }
        my $banner = $s->getline();
        if (!$banner) {
            print "$host: read banner: $!\n";
        } elsif ($banner !~ /^SSH-/) {
            chomp($banner);
            print "$host: bad banner '$banner'\n";
        }
        $s->close();
    }
}

1;
