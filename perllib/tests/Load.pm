#!/usr/bin/perl
#
# Load.pm:
# Check system load against a threshold.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Load.pm,v 1.1 2006-03-24 18:28:14 chris Exp $
#

package Load;

use strict;

use IO::File;

use constant MAX_ACCEPTABLE_LOAD => 15;

sub test () {
    my $f = new IO::File("/proc/loadavg", O_RDONLY);
    if (!$f) {
        print "/proc/loadavg: open: $!\n";
        return;
    }
    my $line = $f->getline();
    if (!$line) {
        print "/proc/loadavg: read: $!\n";
        return;
    }
    chomp($line);
    my ($l1, $l5, $l15) = split(/\s+/, $line);
    if ($l1 > MAX_ACCEPTABLE_LOAD) {
        printf "1-minute load average is %.2f (> %.2f)\n",
                $l1, MAX_ACCEPTABLE_LOAD;
    }
    $f->close();
}

1;
