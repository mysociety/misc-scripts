#!/usr/bin/perl
#
# PB.pm:
# Check that PledgeBank is working (up to a point).
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PB.pm,v 1.4 2007-11-05 08:17:26 francis Exp $
#

package PB;

use strict;

use POSIX qw();

use mySociety::Config;
use mySociety::DBHandle qw(dbh);

use constant PB_CONF_DIR => '/data/vhost/www.pledgebank.com/mysociety/pb/conf';

sub test () {
    return if (!-d PB_CONF_DIR || !-e PB_CONF_DIR . "/general");

    # Mustn't call set_file as root since that would allow an pb->root
    # compromise. So drop privileges.
    my $pb_uid = getpwnam('pb');
    my $pb_gid = getpwnam('pb');
    if (!defined($pb_uid) || !defined($pb_gid)) {
        print "no user/group pb, even though config file exists\n";
        return;
    }
    if (!POSIX::setgid($pb_gid)) {
        print "setgid($pb_gid): $!\n";
        return;
    }
    if (!POSIX::setuid($pb_uid)) {
        print "setuid($pb_uid): $!\n";
        return;
    }
    mySociety::Config::set_file(PB_CONF_DIR . "/general");

    mySociety::DBHandle::configure(
            Name => mySociety::Config::get('PB_DB_NAME'),
            User => mySociety::Config::get('PB_DB_USER'),
            Password => mySociety::Config::get('PB_DB_PASS'),
            Host => mySociety::Config::get('PB_DB_HOST'),
            Port => mySociety::Config::get('PB_DB_PORT'),
        );

    # as of 2006-08-15:
    # 95th percentile signup interval is about 3 hours
    # 99th percentile signup interval is about 6 hours
    # Got bored of errors from even that, so am going for 12 hours.

    my $last_signup_age =
            time() - dbh()->selectrow_array('
                        select extract(epoch from signtime)
                        from signers
                        order by signtime desc
                        limit 1');

    printf("last signup was %d minutes ago", int($last_signup_age / 60))
        if ($last_signup_age > (12 * 3600));

    dbh()->disconnect();
}

1;
