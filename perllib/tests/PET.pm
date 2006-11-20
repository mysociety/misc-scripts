#!/usr/bin/perl
#
# PET.pm:
# Check that petitions.pm.gov.uk is working (up to a point).
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PET.pm,v 1.1 2006-11-20 15:30:26 francis Exp $
#

package PET;

use strict;

use POSIX qw();

use mySociety::Config;
use mySociety::DBHandle qw(dbh);

use constant PET_CONF_DIR => '/data/vhost/petitions.pm.gov.uk/mysociety/pet/conf';

sub test () {
    return if (!-d PET_CONF_DIR || !-e PET_CONF_DIR . "/general");

    # Mustn't call set_file as root since that would allow an pet->root
    # compromise. So drop privileges.
    my $pet_uid = getpwnam('pet');
    my $pet_gid = getpwnam('pet');
    if (!defined($pet_uid) || !defined($pet_gid)) {
        print "no user/group pet, even though config file exists\n";
        return;
    }
    if (!POSIX::setgid($pet_gid)) {
        print "setgid($pet_gid): $!\n";
        return;
    }
    if (!POSIX::setuid($pet_uid)) {
        print "setuid($pet_uid): $!\n";
        return;
    }
    mySociety::Config::set_file(PET_CONF_DIR . "/general");

    mySociety::DBHandle::configure(
            Name => mySociety::Config::get('PET_DB_NAME'),
            User => mySociety::Config::get('PET_DB_USER'),
            Password => mySociety::Config::get('PET_DB_PASS'),
            Host => mySociety::Config::get('PET_DB_HOST'),
            Port => mySociety::Config::get('PET_DB_PORT'),
        );

    # We check only confirmed signups
    my $last_signup_age =
            time() - dbh()->selectrow_array('
                        select extract(epoch from signtime)
                        from signer
                        order by signtime desc
                        where emailsent = \'confirmed\'
                        limit 1');

    # XXX work this out for E-Petitions, at at night vs. day
    # for PledgeBank, as of 2006-08-15:
    # 95th percentile signup interval is about 3 hours
    # 99th percentile signup interval is about 6 hours

    # Signups probably more common in the night
    my $time = POSIX::strftime('%H:%M', localtime());
    my $message_threshold = (0.5 * 3600);
    $message_threshold = (6 * 3600) if ($time lt '09:00' || $time gt '22:00');
 
    printf("last confirmed signup was %d minutes ago", int($last_signup_age / 60))
        if ($last_signup_age > $message_threshold);

    dbh()->disconnect();
}

1;
