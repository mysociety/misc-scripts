#!/usr/bin/perl
#
# FYR.pm:
# Check that FYR appears to be sending messages.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: FYR.pm,v 1.7 2006-09-09 00:18:42 francis Exp $
#

package FYR;

use strict;

use POSIX qw();

use mySociety::Config;
use mySociety::DBHandle qw(dbh);

use constant FYR_CONF_DIR => '/data/vhost/www.writetothem.com/mysociety/fyr/conf';

sub test () {
    return if (!-d FYR_CONF_DIR || !-e FYR_CONF_DIR . "/general");
    
    # Mustn't call set_file as root since that would allow an fyr->root
    # compromise. So drop privileges.
    my $fyr_uid = getpwnam('fyr');
    my $fyr_gid = getpwnam('fyr');
    if (!defined($fyr_uid) || !defined($fyr_gid)) {
        print "no user/group fyr, even though config file exists\n";
        return;
    }
    if (!POSIX::setgid($fyr_gid)) {
        print "setgid($fyr_gid): $!\n";
        return;
    }
    if (!POSIX::setuid($fyr_uid)) {
        print "setuid($fyr_uid): $!\n";
        return;
    }
    mySociety::Config::set_file(FYR_CONF_DIR . "/general");

    mySociety::DBHandle::configure(
            Name => mySociety::Config::get('FYR_QUEUE_DB_NAME'),
            User => mySociety::Config::get('FYR_QUEUE_DB_USER'),
            Password => mySociety::Config::get('FYR_QUEUE_DB_PASS'),
            Host => mySociety::Config::get('FYR_QUEUE_DB_HOST'),
            Port => mySociety::Config::get('FYR_QUEUE_DB_PORT'),
        );

    my $last_message_age =
            time() - dbh()->selectrow_array('
                        select created from message
                        order by created desc
                        limit 1');
    my $last_fax_age =
            time() - dbh()->selectrow_array('
                        select dispatched from message
                        where dispatched is not null
                            and recipient_fax is not null
                            and recipient_email is null
                        order by dispatched desc
                        limit 1');

    # We only include faxes/emails that have had no delivery attempts in our
    # count of pending messages, because it is not useful for the test to fire
    # just because (say) an email is sitting on the queue because of a
    # transient failure at the remote site.
    my $n_ready_faxes =
            dbh()->selectrow_array("
                        select count(id) from message
                        where state = 'ready'
                            and not frozen
                            and numactions = 0
                            and recipient_fax is not null");

    my $last_email_age =
            time() - dbh()->selectrow_array('
                        select dispatched from message
                        where dispatched is not null
                            and recipient_fax is null
                            and recipient_email is not null
                        order by dispatched desc
                        limit 1');
    my $n_ready_emails =
            dbh()->selectrow_array("
                        select count(id) from message
                        where state = 'ready'
                            and not frozen
                            and numactions = 0
                            and recipient_email is not null
                            and (dispatched is null
                                or dispatched < ? - 7200)", {}, time());

    my $time = POSIX::strftime('%H:%M', localtime());

    # Most FYR messages are sent between 0900h and 2200h local time. Check that
    # a message has been submitted within 45 minutes during peak hours or
    # within 4 hours during off hours.
    my $message_threshold = 2700;
    $message_threshold = 14400 if ($time lt '09:00' || $time gt '22:00');
    
    printf("last message was submitted %d minutes ago\n",
        int($last_message_age / 60))
            if ($last_message_age > $message_threshold);
    
    printf("last fax was sent %d minutes ago; %d pending\n",
        int($last_fax_age / 60), $n_ready_faxes)
            if ($time ge '08:20' && $time le '20:00'
                && $n_ready_faxes > 0 && $last_fax_age > 1200);

    printf("last email was sent %d minutes ago; %d pending\n",
        int($last_email_age / 60), $n_ready_emails)
            if ($n_ready_emails > 0 && $last_email_age > 1200);

    # XXX maybe ought to check for messages being confirmed.

    dbh()->disconnect();
}

1;
