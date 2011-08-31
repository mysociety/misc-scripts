#!/usr/bin/perl
#
# Memory.pm:
# Test to make sure undue amount of swap aren't being used.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Memory.pm,v 1.9 2011-08-31 11:16:52 matthew Exp $
#

package Memory;

use strict;

use IO::File;

use constant MIN_SWAP_FRACTION => 0.50; # % of swap that must be free

sub email() { return 'sysadmin'; }

sub test () {
    # The format of /proc/meminfo differs between 2.4 and 2.6 series kernels
    # (or some other configuration difference). So we use /proc/swaps instead.
    
    my $f = new IO::File('/proc/swaps', O_RDONLY);
    if (!$f) {
        print "/proc/swaps: open: $!\n";
        return;
    }
    $f->getline();

    # list of memory stats
    my $total_used = 0;
    my $total = 0;
    while (my $mem = $f->getline()) {
        chomp($mem);
        my ($device, $type, $size, $used, $priority) = split(/\s+/, $mem);
        $total_used += $used;
        $total += $size;
    }
    my $free = $total - $total_used;
    if (!$total) {
        print "/proc/swaps: read: $!\n";
        return;
    }
    if ($free / $total < MIN_SWAP_FRACTION) {
        printf "swap: only %d / %d MB (%.1f%% < %.1f%%) free\n",
                $free / (1024), $total / (1024),
                100 * $free / $total,
                100 * MIN_SWAP_FRACTION;
    }
}

1;
