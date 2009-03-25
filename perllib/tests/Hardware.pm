#!/usr/bin/perl
#
# Hardware.pm:
# Check various hardware statuses
#
# $Id: Hardware.pm,v 1.1 2009-03-25 18:51:10 root Exp $
#

package Hardware;

use strict;

use IO::File;

sub test () {

# Tets for type of machine
# Test to see if omreport exists
my $f;
if ( -e "/usr/sbin/omreport" ) {
	$f = `omreport storage pdisk controller=0`;
    # If no controller nothing we can look at AFAIK
    if ($f =~ /^Invalid controller value/)
    {
        #No controllers found so we can't do anything
        exit 0;
    }
} else {
	#Software not installed
	exit 0;
}

my $current_disk_name;

foreach (split (/\n/,$f)) {
        my $line = $_ ;

        if ( $line =~ /Name \W+: (.+)/ )
        {
            $current_disk_name = $1;
        }

        
        if ( $line =~ /State \W+: (\w+)/ )
        {
            if (($1 ne "Ready") && ($1 ne "Online"))
            {
                print "Failure of $current_disk_name - State: $1\n";
            }
        }
    }

}


1;
