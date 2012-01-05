#!/usr/bin/perl
#
# Hardware.pm:
# Check various hardware statuses
#
# $Id: Hardware.pm,v 1.6 2012-01-05 23:09:29 alexjs Exp $
#

package Hardware;

use strict;

use IO::File;

sub email() { return 'hardware'; }

sub test () {

    my $f;

    # For vulcan 
    if ( -e "/root/areca/cli" ) {
        $f = `/root/areca/cli disk info | grep Failed`;

        if ($f) {
            print "$f";
        }
        return;
   } 

    # For our m247 Dell Machines
    if ( -e "/usr/sbin/tw_cli.x86_64" ) {
        $f = `/usr/sbin/tw_cli.x86_64 /c0/u0 show | grep DISK | egrep -ve '(OK|VERIFYING)'`;
        if ($f) {
            print "$f";
        }
        return;
    }
}


1;
