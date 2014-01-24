#!/usr/bin/perl
#
# Fork.pm:
# Test that we can start a process, allocate a bit of memory, and exit.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Fork.pm,v 1.2 2010-10-08 15:46:54 matthew Exp $
#

package Fork;

use strict;

use POSIX;

sub email() { return 'sysadmin'; }

sub test () {
    my $pid = fork();
    if (!defined($pid)) {   
        print "fork: $!\n";
        return;
    } elsif ($pid == 0) {
        my $x = 'A' x (1024 * 1024);
        $x =~ s/A/B/;
        exit(0);
    } else {
        wait();
        if ($?) {
            if (WIFSIGNALED($?)) {
                print "test process died with signal ", WTERMSIG($?), "\n";
            } else {
                print "test process exited with failure status ", WEXITSTATUS($?), "\n";
            }
        }
    }
}

1;
