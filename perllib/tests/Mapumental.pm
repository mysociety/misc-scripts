#!/usr/bin/perl
#
# Mapumental.pm:
# Check that demo daemon is running.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Mapumental.pm,v 1.6 2012-07-24 18:53:47 duncan Exp $

package Mapumental;

use strict;

use constant COL_CONF_DIR => '/data/vhost/mapumental.channel4.com/mysociety/iso/conf';
use constant PTD_CONF_DIR => '/data/vhost/ptdaemon.mapumental.com/';

sub email() { return 'mapumental'; }

sub test () {
    #test_isodaemon();
    test_ptdaemon();
}

sub test_isodaemon () {
    return if (!-d COL_CONF_DIR || !-e COL_CONF_DIR . "/general");
    my @procs = map { chomp; $_ } `ps ax -o user:20,command |grep isodaemon|grep -v grep|cut -d" " -f 1|sort|uniq`;
    unless (scalar @procs == 1 && $procs[0] eq 'col') {
        print "isodaemon is not running on arrow\n";
    }
}

sub _read_file ($) {
    my ($filename) = @_;
    open my $fh, "<", $filename or die "Failed to open $filename: $!\n";
    local $/; # enable localized slurp mode
    return scalar <$fh>;
}

sub test_ptdaemon () {
    return if (!-d PTD_CONF_DIR);
    
    my $pidfile = PTD_CONF_DIR . "/ptdaemon.pid";
    if (! -e $pidfile) {
        print "$pidfile does not exist\n";
        return;
    }
    my $pid = _read_file $pidfile;
    chomp $pid;
    my $status = system("/bin/ps -p $pid > /dev/null");
    if ($status != 0) {
        print "ptdaemon not running (expected pid $pid)\n";
    }
}

1;
