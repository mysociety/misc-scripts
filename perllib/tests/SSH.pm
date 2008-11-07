#!/usr/bin/perl
#
# SSH.pm:
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: SSH.pm,v 1.8 2008-11-07 17:26:10 root Exp $
#

package SSH;

use strict;

use IO::Socket;

my @hostlist = qw(
        sponge.ukcod.org.uk

        bitter.ukcod.org.uk
        tea.ukcod.org.uk
        balti.ukcod.org.uk

        steak.ukcod.org.uk

        water.ukcod.org.uk
        cake.ukcod.org.uk
        sandich.ukcod.org.uk
        pudding.ukcod.org.uk
    );

# whisky.ukcod.org.uk
# peas.ukcod.org.uk

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
