#!/usr/bin/perl
#
# Hardware.pm:
# Check various hardware statuses
#
# $Id: Hardware.pm,v 1.10 2012-06-14 09:25:02 ian Exp $
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
        my $controller = `/usr/sbin/tw_cli.x86_64 show | tail -n2`;
        $controller =~ s/(c[0-9]).*/$1/;
        $controller =~ s/\s*$//g; 
        chomp($controller);
        $f = `/usr/sbin/tw_cli.x86_64 "/$controller/u0 show" | grep DISK | egrep -ve '(OK|VERIFYING)'`;
        if ($f) {
            print "$f";
        }
        return;
    }
}
test();

1;
