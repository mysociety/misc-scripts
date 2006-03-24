#!/usr/bin/perl
#
# Web.pm:
# Test that websites are up.
#
# Nasty because we want to check each host for multihomed site.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Web.pm,v 1.1 2006-03-24 18:28:14 chris Exp $
#

package Web;

use strict;

use IO::Socket;
use IO::Socket::SSL;
use Socket;
use Time::HiRes qw(time);

my @pages = qw(
        http://www.mysociety.org/
        http://www.mysociety.org/moin.cgi
        http://www.mysociety.org/volunteertasks?skills=nontech

        http://www.pledgebank.com/
        http://www.pledgebank.com/rights

        http://www.writetothem.com/
        http://www.writetothem.com/who?pc=CB4+1EP
        http://www.writetothem.com/who?pc=SE26+6SS

        http://www.hearfromyourmp.com/
        http://www.hearfromyourmp.com/league

        https://secure.mysociety.org/
        https://secure.mysociety.org/cvstrac/
        https://secure.mysociety.org/track/webbug.png
    );

use constant CONNECT_TIME_MAX => 0.5;
use constant SEND_REQUEST_TIME_MAX => 1;
use constant GET_RESPONSELINE_TIME_MAX => 10;
use constant GET_HEADERS_TIME_MAX => 5;
use constant GET_BODY_TIME_MAX => 10;
use constant TOTAL_TIME_MAX => 20;

sub test () {
    foreach my $page (@pages) {
        my ($hostname, $path) = ($page =~ m#^https?://([^/]+)(/.*)$#);
        if (!$hostname || !$path) {
            print "$page: bad URL\n";
            next;
        }
        # now we need to resolve the hostname; if there's more than one
        # hostname, we must try the query against each of them.
        my @x = gethostbyname($hostname);
        if (!@x) {
            print "$page -> $hostname: unable to resolve address: $!\n";
            next;
        }
        my ($a, $b, $n, $len, @addrs) = @x;
        if ($len != 4) {
            print "$page -> $hostname: length of addresses returned is not 4 bytes\n";
            next;
        }
        @addrs = map { inet_ntoa($_) } @addrs;
        my $port = ($page =~ m#http://# ? 80 : 443);
        foreach my $addr (@addrs) {
            my $s;
            my $desc = "$page -> $hostname:$port";

            my $t_start = time();
            if ($port == 80) {
                $s = new IO::Socket::INET(
                                Type => SOCK_STREAM,
                                Proto => 'tcp',
                                PeerHost => $addr,
                                PeerPort => $port
                            );
                if (!$s) {
                    print "$desc: $!\n";
                    goto end;
                }
            } else {
                $desc .= '(SSL)';
                $s = new IO::Socket::SSL("$addr:$port");
                if (!$s) {
                    print "$desc: $!\n";
                    goto end;
                }
            }

            my $t_connected = time();

            if ($t_connected - $t_start > CONNECT_TIME_MAX) {   
                printf "%s: connect time %fs (> %fs)\n",
                        $desc, $t_connected - $t_start, CONNECT_TIME_MAX;
            }

            if (!$s->print(
                    "GET $path HTTP/1.0\r\n" .
                    "Host: $hostname\r\n" .
                    "Connection: close\r\n" .
                    "\r\n"
                )) {
                print "$desc: send headers: $!\n";
            }
            $s->flush();

            my $t_sent_headers = time();

            if ($t_sent_headers - $t_connected > SEND_REQUEST_TIME_MAX) {
                printf "%s: send request time %fs (> %fs)\n",
                        $desc, $t_sent_headers - $t_connected, SEND_REQUEST_TIME_MAX;
            }

            local $/ = "\r\n";
            
            my $responseline = $s->getline();
            if (!$responseline) {
                print "$desc: read response line: $!\n";
                goto end;
            }

            my $t_got_responseline = time();
            if ($t_got_responseline - $t_sent_headers > GET_RESPONSELINE_TIME_MAX) {
                printf "%s: receive response line %fs (> %fs)\n",
                        $desc, $t_got_responseline - $t_sent_headers, GET_RESPONSELINE_TIME_MAX;
            }

            $responseline =~ s/\r\n$//;
            if ($responseline !~ m#^HTTP/1.[01] ([1-9][0-9]{2}.+)$#) {
                print "$desc: bad response line '$responseline'\n";
                goto end;
            }
            my $status = $1;
            if ($status !~ /^200 /) {
                print "$desc: failure status '$status'\n";
            }

            my $length;
            while (1) {
                my $header = $s->getline();
                if (!$header) {
                    print "$desc: reading headers: $!";
                    goto end;
                }
                $header =~ s/\r\n$//;
                last if ($header eq '');
                if ($header !~ m#^[A-Za-z0-9-]+: (.+)$#) {
                    print "$desc: bad header '$header'\n";
                    goto end;
                }

                $length = $1 if ($header =~ m/^Content-Type: \s*([1-9]\d*)$/i);
            }

            my $t_got_headers = time();
            if ($t_got_headers - $t_got_responseline > GET_HEADERS_TIME_MAX) {
                printf "%s: receive headers %fs (> %fs)\n",
                        $desc, $t_got_headers - $t_got_responseline, GET_HEADERS_TIME_MAX;
            }

            my $nread = 0;
            while (1) {
                my $buf;
                my $n = $s->read($buf, 8192);
                if (!defined($n)) {
                    print "$desc: while reading response (got $nread bytes): $!\n";
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

            my $t_got_body = time();
            if ($t_got_body - $t_got_headers > GET_BODY_TIME_MAX) {
                printf "%s: receive %d bytes of content %fs (> %fs)\n",
                        $desc, $nread, $t_got_body - $t_got_headers, GET_BODY_TIME_MAX;
            }

            my $t_done = time();
            if ($t_done - $t_start > TOTAL_TIME_MAX) {
                printf "%s: total time %fs (> %fs)\n",
                        $desc, $t_done - $t_start, TOTAL_TIME_MAX;
            }

end:
            $s->close() if ($s);
        }
    }
}

1;
