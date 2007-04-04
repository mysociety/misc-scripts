#!/usr/bin/perl
#
# Entropy.pm:
# Test to make sure there is at least some entropy on the server
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Entropy.pm,v 1.1 2007-04-04 14:14:39 francis Exp $
#

package Entropy;

use strict;

use IO::File;

use constant MIN_ENTROPY => 10; # amount of entropy to expect

sub test () {
    my $f = new IO::File('/proc/sys/kernel/random/entropy_avail', O_RDONLY);
    if (!$f) {
        print "/proc/sys/kernel/random/entropy_avail: open: $!\n";
        return;
    }
    my $entropy;
    $entropy = $f->getline();
    if (!$entropy) {
        print "/proc/sys/kernel/random/entropy_avail: read: $!\n";
        return;
    }

    if ($entropy < MIN_ENTROPY) {
        printf "entropy: only %d available\n", $entropy;
    }
}

1;
