#!/usr/bin/perl
#
# Hardware.pm:
# Check various hardware statuses
#
# $Id: Hardware.pm,v 1.7 2012-02-06 09:02:37 alexjs Exp $
#

package Hardware;

use strict;

use IO::File;

use Sys::Hostname;

my $host;
$host = hostname;

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
        my $controller;
        if ( $host == "samson" ) {
            $controller = "c4";
        } else {
            $controller = "c0";
        }
        
        $f = `/usr/sbin/tw_cli.x86_64 "/$controller/u0 show" | grep DISK | egrep -ve '(OK|VERIFYING)'`;
        if ($f) {
            print "$f";
        }
        return;
    }
}


1;
