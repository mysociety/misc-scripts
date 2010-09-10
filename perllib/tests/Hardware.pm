#!/usr/bin/perl
#
# Hardware.pm:
# Check various hardware statuses
#
# $Id: Hardware.pm,v 1.3 2010-09-10 18:16:07 francis Exp $
#

package Hardware;

use strict;

use IO::File;

sub test () {

    my $f;

    # For marmite and stilton
    if ( -e "/root/areca/cli" ) {
        $f = `/root/areca/cli disk info | grep Failed`;

        if ($f) {
            print "$f";
        }
        return;
   } 

    # For some Dell machines
    if ( -e "/usr/sbin/omreport" ) {
        $f = `omreport storage pdisk controller=0`;

        # If no controller nothing we can look at AFAIK
        if ($f =~ /^Invalid controller value/) {
            #No controllers found so we can't do anything
            $f="";
        }

        if ($f) {
            my $current_disk_name;

            foreach (split (/\n/,$f)) {
                my $line = $_ ;

                if ( $line =~ /Name \W+: (.+)/ ) {
                    $current_disk_name = $1;
                }
                
                if ( $line =~ /State \W+: (\w+)/ ) {
                    if (($1 ne "Ready") && ($1 ne "Online")) {
                        print "Failure of $current_disk_name - State: $1\n";
                    }
                }
            }
        }
        return;
    }
}


1;
