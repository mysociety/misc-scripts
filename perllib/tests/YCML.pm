#!/usr/bin/perl
#
# YCML.pm:
# Check that HearFromYourMP is working (up to a point).
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: YCML.pm,v 1.3 2006-08-16 08:52:37 chris Exp $
#

package YCML;

use strict;

use POSIX qw();

use mySociety::Config;
use mySociety::DBHandle qw(dbh);

use constant YCML_CONF_DIR => '/data/vhost/www.hearfromyourmp.com/mysociety/ycml/conf';

sub test () {
    return if (!-d YCML_CONF_DIR || !-e YCML_CONF_DIR . "/general");

    # Mustn't call set_file as root since that would allow an ycml->root
    # compromise. So drop privileges.
    my $ycml_uid = getpwnam('ycml');
    my $ycml_gid = getpwnam('ycml');
    if (!defined($ycml_uid) || !defined($ycml_gid)) {
        print "no user/group ycml, even though config file exists\n";
        return;
    }
    if (!POSIX::setgid($ycml_gid)) {
        print "setgid($ycml_gid): $!\n";
        return;
    }
    if (!POSIX::setuid($ycml_uid)) {
        print "setuid($ycml_uid): $!\n";
        return;
    }
    mySociety::Config::set_file(YCML_CONF_DIR . "/general");

    mySociety::DBHandle::configure(
            Name => mySociety::Config::get('YCML_DB_NAME'),
            User => mySociety::Config::get('YCML_DB_USER'),
            Password => mySociety::Config::get('YCML_DB_PASS'),
            Host => mySociety::Config::get('YCML_DB_HOST'),
            Port => mySociety::Config::get('YCML_DB_PORT'),
        );

    # as of 2006-08-15:
    # 95th percentile signup interval is about 1.5 hours
    # 99th percentile signup interval is about 6.5 hours

    my $last_signup_age =
            time() - dbh()->selectrow_array('
                        select extract(epoch from creation_time)
                        from constituent
                        order by creation_time desc
                        limit 1');

    printf("last signup was %d minutes ago", int($last_signup_age / 60))
        if ($last_signup_age > (6.5 * 3600));

    dbh()->disconnect();
}

1;
