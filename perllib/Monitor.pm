#!/usr/bin/perl
#
# Monitor.pm:
# Shared functions for tests.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Monitor.pm,v 1.1 2010-10-18 11:44:08 matthew Exp $
#

package Monitor;

use strict;

use IO::Socket;
use IO::Socket::SSL;
use Socket;
use Time::HiRes qw(time alarm);

use constant CONNECT_TIME_MAX => 0.5;
use constant SEND_REQUEST_TIME_MAX => 1;
use constant GET_RESPONSELINE_TIME_MAX => 10;
use constant GET_RESPONSELINE_TIME_MAX_YCML_LEAGUE => 20;
use constant GET_HEADERS_TIME_MAX => 5;
use constant GET_BODY_TIME_MAX => 10;
use constant TOTAL_TIME_MAX => 20;

sub test_web ($) {
    local $SIG{ALRM} = sub { die "timeout"; };
    my $page = shift;
    my ($hostname, $path) = ($page =~ m{^https?://([^/]+)(/.*)$});
    if (!$hostname || !$path) {
        print "$page: bad URL\n";
        return;
    }

    my $override_port;
    if ($hostname =~ /^(.+):([1-9]\d*)$/) {
        $hostname = $1;
        $override_port = $2;
    }
        
    # now we need to resolve the hostname; if there's more than one
    # hostname, we must try the query against each of them.
    my @x = gethostbyname($hostname);
    if (!@x) {
        print "$page -> $hostname: unable to resolve address: $!\n";
        return;
    }
    my ($a, $b, $n, $len, @addrs) = @x;
    if ($len != 4) {
        print "$page -> $hostname: length of addresses returned is not 4 bytes\n";
        return;
    }
    @addrs = map { inet_ntoa($_) } @addrs;
    my $port = $override_port;
    $port ||= ($page =~ m#http://# ? 80 : 443);
    foreach my $addr (@addrs) {
        my $s;
        my $desc = "$page -> $addr:$port";
        #print "Web: $desc\n";
        my $what = "connecting";

        eval {
            if ($port == 80) {
                alarm(CONNECT_TIME_MAX);
                $s = new IO::Socket::INET(
                                Type => SOCK_STREAM,
                                Proto => 'tcp',
                                PeerHost => $addr,
                                PeerPort => $port
                            );
                if (!$s) {
                    print "$desc: $what: $!\n";
                    goto end;
                }
            } else {
                # Hack.
                alarm(3 * CONNECT_TIME_MAX);
                $desc .= '(SSL)';
                $s = new IO::Socket::SSL("$addr:$port");
                if (!$s) {
                    print "$desc: $what: $!\n";
                    goto end;
                }
            }

            my $t_connected = time();

            $what = "sending request";
            alarm(SEND_REQUEST_TIME_MAX);

            if (!$s->print(
                    "GET $path HTTP/1.0\r\n" .
                    "Host: $hostname\r\n" .
                    "Connection: close\r\n" .
                    "\r\n"
                )) {
                print "$desc: $what: $!\n";
                goto end;
            }
            $s->flush();

            $what = "waiting for response line";
            if ($page eq "http://www.hearfromyourmp.com/league") {
                alarm(GET_RESPONSELINE_TIME_MAX_YCML_LEAGUE);
            } else {
                alarm(GET_RESPONSELINE_TIME_MAX);
            }
            local $/ = "\r\n";
            
            my $responseline = $s->getline();
            if (!$responseline) {
                print "$desc: $what: $!\n";
                goto end;
            }

            $responseline =~ s/\r\n$//;
            if ($responseline !~ m/^HTTP\/1.[01] ([1-9][0-9]{2}.+)$/) {
                print "$desc: bad response line '$responseline'\n";
                goto end;
            }
            my $status = $1;
            if ($status !~ /^200 /) {
                print "$desc: failure status '$status'\n";
            }

            $what = "receiving headers";
            alarm(GET_HEADERS_TIME_MAX);

            my $length;
            while (1) {
                my $header = $s->getline();
                if (!$header) {
                    print "$desc: $what: $!";
                    goto end;
                }
                $header =~ s/\r\n$//;
                last if ($header eq '');
                if ($header !~ m/^[A-Za-z0-9-]+: (.+)$/) {
                    print "$desc: bad header '$header'\n";
                    goto end;
                }

                $length = $1 if ($header =~ m/^Content-Type: \s*([1-9]\d*)$/i);
            }

            $what = "receiving response body";
            alarm(GET_BODY_TIME_MAX);

            my $nread = 0;
            while (1) {
                my $buf;
                my $n = $s->read($buf, 8192);
                if (!defined($n)) {
                    print "$desc: $what (got $nread bytes): $!\n";
                    goto end;
                } elsif ($n == 0) {
                    if (defined($length) && $nread < $length) {
                        print "$desc: truncated body (got $nread of $length bytes)\n";
                        goto end;
                    }
                    last;
                }
                $nread += $n;
            }

            alarm(0);

            my $t_done = time();

end:
            alarm(0);
            $s->close() if ($s);
        };

        if ($@) {
            if ($@ =~ /timeout/) {
                print "$desc: $what: timed out\n";
            } else {
                die $@;
            }
        }
    }
}

1;
