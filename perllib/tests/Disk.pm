#!/usr/bin/perl
#
# Disk.pm:
# Disk space.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Disk.pm,v 1.6 2010-10-08 15:46:54 matthew Exp $
#

package Disk;

use strict;

use IO::Pipe;

use constant PROG_DF => '/bin/df';

use constant MIN_DISK_FRACTION => 0.05; # XXX temp should be 0.1

sub email() { return 'serious'; }

sub test () {
    my $p = new IO::Pipe();
    if (!$p) {
        print "pipe: $!\n";
        return;
    }
    # -k == 1KB blocks, -P for each on one line -l == local mounts only
    if (!$p->reader(PROG_DF, '-k', '-P', '-l')) {
        print "fork/exec df: $!\n";
        return;
    }
    $p->getline();
    while (my $line = $p->getline()) {
        chomp($line);
        my ($fs, $total, $used, $available, $use, $mountpoint) = split(/\s+/, $line);
        if ((1. * $available) / $total < MIN_DISK_FRACTION) {
            printf "%s (fs %s): only %.1fGB / %.1fGB (%.1f%% < %.1f%%) available\n",
                    $mountpoint, $fs,
                    $available / (2. ** 20), $total / (2. ** 20),
                    100 * $available / $total, 100 * MIN_DISK_FRACTION;
        }
    }

    if ($p->error()) {
        print "read from df: $!\n";
        return;
    }

    $p->close();
}

1;
