#!/usr/bin/perl
#
# SSH.pm:
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: SSH.pm,v 1.7 2008-03-24 22:39:12 keith Exp $
#

package SSH;

use strict;

use IO::Socket;

my @hostlist = qw(
        sponge.ukcod.org.uk

        bitter.ukcod.org.uk
        tea.ukcod.org.uk
        balti.ukcod.org.uk

        peas.ukcod.org.uk
        steak.ukcod.org.uk

        whisky.ukcod.org.uk
        water.ukcod.org.uk
    );

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
