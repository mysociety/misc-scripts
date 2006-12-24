#!/usr/bin/perl
#
# Memory.pm:
# Test for available memory.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Memory.pm,v 1.2 2006-12-24 00:55:07 francis Exp $
#

package Memory;

use strict;

use IO::File;

use constant MIN_MEM_FRACTION => 0.01;
use constant MIN_SWAP_FRACTION => 0.5;

sub test () {
    # XXX the format of /proc/meminfo seems to differ between 2.4 and 2.6
    # series kernels (or some other configuration difference). This test
    # is currently coded for 2.4 kernels.
    
    my $f = new IO::File('/proc/meminfo', O_RDONLY);
    if (!$f) {
        print "/proc/meminfo: open: $!\n";
        return;
    }
    $f->getline();

    # list of memory stats
    my $mem;
    $mem = $f->getline();
    if (!$mem) {
        print "/proc/meminfo: read: $!\n";
        return;
    }
    chomp($mem);
    my ($label, $total, $used, $free, $shared, $buffers, $cached) = split(/\s+/, $mem);
    if ($free / $total < MIN_MEM_FRACTION) {
        printf "memory: only %d / %dMB (%.1f%% < %.1f%%) free\n",
                $free / (1024 * 1024), $total / (1024 * 1024),
                100 * $free / $total,
                100 * MIN_MEM_FRACTION;
    }
    $mem = $f->getline();
    if (!$mem) {
        print "/proc/meminfo: read: $!\n";
        return;
    }
    chomp($mem);
    ($label, $total, $used, $free, $shared, $buffers, $cached) = split(/\s+/, $mem);
    if ($free / $total < MIN_SWAP_FRACTION) {
        printf "swap: only %d / %dMB (%.1f%% < %.1f%%) free\n",
                $free / (1024 * 1024), $total / (1024 * 1024),
                100 * $free / $total,
                100 * MIN_SWAP_FRACTION;
    }
}

1;
