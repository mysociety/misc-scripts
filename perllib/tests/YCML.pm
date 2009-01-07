#!/usr/bin/perl
#
# YCML.pm:
# Check that HearFromYourMP is working (up to a point).
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: YCML.pm,v 1.8 2009-01-07 18:26:46 matthew Exp $
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

    my $time = POSIX::strftime('%H:%M', localtime());

    my $age_threshold = 6 * 3600;
    $age_threshold = 12 * 3600 if ($time lt '10:00' || $time gt '22:00');

    my $last_signup_age =
            time() - dbh()->selectrow_array('
                        select extract(epoch from creation_time)
                        from constituent
                        order by creation_time desc
                        limit 1');

    printf("last signup was %d minutes ago\n", int($last_signup_age / 60))
        if ($last_signup_age > $age_threshold);

    my $q = dbh()->selectall_arrayref("select id, area_id,
        (select count(*) from message_sent where message_id=message.id) as sent
        from message
            where state='approved'
            and (select count(*) from message_sent where message_id=message.id)=0
            and posted < ms_current_timestamp() - '1 hour'::interval", { Slice => {} });
    foreach (@$q) {
        print "* Message for area $_->{area_id} is >1 hour old, but has had no emails sent out yet\n";
    }

    dbh()->disconnect();
}

1;
