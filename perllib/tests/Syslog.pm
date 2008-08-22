#!/usr/bin/perl
#
# Syslog.pm:
# Verify that we can send messages to syslog, and that they are recorded.
# 
# This doesn't really check that syslog is working, just that a single log
# file grows. That's a reasonably useful test anyway.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Syslog.pm,v 1.2 2008-08-22 09:29:27 matthew Exp $
#

package Syslog;

use strict;

use Fcntl;
use File::stat;
use IO::Socket;
use POSIX;

my $logfile = "/var/log/all.log";
# XXX Hack as I'm fed up of emails
$logfile = '/var/log/messages' unless -e $logfile;

sub test () {
    my $st1 = stat($logfile);
    if (!$st1) {
        print "$logfile: stat: $!\n";
        return;
    }

    my $S = new IO::Socket::UNIX(Type => SOCK_DGRAM, Peer => '/dev/log');
    if (!$S) {
        print "socket: $!\n";
        return;
    }

    if (!fcntl($S, F_SETFL, O_NONBLOCK)) {
        print "fcntl(F_SETFL, O_NONBLOCK: $!\n";
        return;
    }

    my $hostname = (uname())[1];

    if (!$S->syswrite(
                    "<29>" # facility 3 ("system daemons"); priority 5 ("notice")
                    . strftime('%b %e %H:%M:%S ', localtime(time()))
                    . "monitor[$$]: test message")) {
        print "send to syslog: $!\n";
        return;
    }

    sleep(1);

    my $st2 = stat($logfile);
    if (!$st2) {
        print "$logfile: stat: $!\n";
        return;
    }
    if ($st2->size() <= $st1->size() && $st1->ino() == $st2->ino()) {
        print "$logfile did not grow after sending log message\n";
    }
}

1;
