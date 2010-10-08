#!/usr/bin/perl
#
# Memory.pm:
# Test to make sure undue amount of swap aren't being used.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Memory.pm,v 1.8 2010-10-08 15:46:54 matthew Exp $
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
    my $mem;
    $mem = $f->getline();
    if (!$mem) {
        print "/proc/swaps: read: $!\n";
        return;
    }
    chomp($mem);
    my ($device, $type, $total, $used, $priority) = split(/\s+/, $mem);
    my $free = ($total - $used);
    if ($free / $total < MIN_SWAP_FRACTION) {
        printf "swap: only %d / %d MB (%.1f%% < %.1f%%) free\n",
                $free / (1024), $total / (1024),
                100 * $free / $total,
                100 * MIN_SWAP_FRACTION;
    }

    # Removed this so we can have more than 1
    # swap area if required. Don't really need to add up
    # since if we are using half of one swap then we have
    # a problem and should go buy some more memory.
    #
    # check there are no more swap devices
    #if ($f->getline()) {
    #    printf "swap: there are multiple swap devices\n";
    #}
}

1;
