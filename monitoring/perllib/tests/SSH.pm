#!/usr/bin/perl
#
# SSH.pm:
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: SSH.pm,v 1.27 2012-08-22 13:58:47 ian Exp $
#

package SSH;

use strict;

use IO::Socket;

my @hostlist = qw(
        arrow.ukcod.org.uk
        dart.ukcod.org.uk
        eclipse.ukcod.org.uk
        majestic.ukcod.org.uk
        phoenix.ukcod.org.uk
        rocket.ukcod.org.uk
        samson.ukcod.org.uk
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
