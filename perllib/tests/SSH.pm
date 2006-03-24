#!/usr/bin/perl
#
# SSH.pm:
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: SSH.pm,v 1.1 2006-03-24 21:19:18 chris Exp $
#

package SSH;

use strict;

use IO::Socket;

my @hostlist = qw(
        very.unfortu.net
        bitter.ukcod.org.uk
        tea.ukcod.org.uk
        cake.ukcod.org.uk
        cerulean.beasts.org
    );

sub test () {
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
