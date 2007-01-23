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
# $Id: Web.pm,v 1.11 2007-01-23 15:19:09 francis Exp $
#

package Web;

use strict;

use IO::Socket;
use IO::Socket::SSL;
use Socket;
use Time::HiRes qw(time alarm);

my @pages = qw(
        http://www.mysociety.org/
        http://www.mysociety.org/moin.cgi
        http://www.mysociety.org/volunteertasks?skills=nontech

        http://www.mysociety.co.uk/

        http://www.pledgebank.com/
        http://www.pledgebank.com/rights
        http://www.pledgebank.com/faq
        http://promise.livesimply.org.uk/

        http://www.theyworkforyou.com/
        http://www.theyworkforyou.com/mp/tony_blair/sedgefield

        http://www.writetothem.com/
        http://www.writetothem.com/who?pc=CB4+1EP
        http://www.writetothem.com/who?pc=SE26+6SS

        http://www.hearfromyourmp.com/
        http://www.hearfromyourmp.com/league
        http://www.hearfromyourmp.com/view/message/91

        http://www.downingstreetsays.com/

        http://petitions.pm.gov.uk/
        http://petitions.pm.gov.uk/huntingactrepeal/

        https://secure.mysociety.org/
        https://secure.mysociety.org/cvstrac/
        https://secure.mysociety.org/track/webbug.png

        http://gaze.mysociety.org/gaze?R1%3A0%2C37%3AGaze.get_radius_containing_population%2CL1%3A3%2CT14%3A51.41281945404%2CT17%3A-0.29430381185079%2CT6%3A200000%2C
        http://gaze.mysociety.org/gaze?R1%3A0%2C16%3AGaze.find_places%2CL1%3A5%2CT2%3AGB%2CNT7%3ANewport%2CI2%3A10%2CI1%3A0%2C
    );

use constant CONNECT_TIME_MAX => 0.5;
use constant SEND_REQUEST_TIME_MAX => 1;
use constant GET_RESPONSELINE_TIME_MAX => 10;
use constant GET_RESPONSELINE_TIME_MAX_YCML_LEAGUE => 20;
use constant GET_HEADERS_TIME_MAX => 5;
use constant GET_BODY_TIME_MAX => 10;
use constant TOTAL_TIME_MAX => 20;

sub test () {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');

    local $SIG{ALRM} = sub { die "timeout"; };
    foreach my $page (@pages) {
        my ($hostname, $path) = ($page =~ m#^https?://([^/]+)(/.*)$#);
        if (!$hostname || !$path) {
            print "$page: bad URL\n";
            next;
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
            next;
        }
        my ($a, $b, $n, $len, @addrs) = @x;
        if ($len != 4) {
            print "$page -> $hostname: length of addresses returned is not 4 bytes\n";
            next;
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
                if ($responseline !~ m#^HTTP/1.[01] ([1-9][0-9]{2}.+)$#) {
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
                    if ($header !~ m#^[A-Za-z0-9-]+: (.+)$#) {
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
}

1;
