#!/usr/bin/perl
#
# FYR.pm:
# Check that FYR appears to be sending messages.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: FYR.pm,v 1.1 2006-08-15 16:41:35 chris Exp $
#

package FYR;

use strict;

use mySociety::Config;
use mySociety::DBHandle;

use constant FYR_CONF_DIR => '/data/vhost/www.writetothem.com/mysociety/fyr/conf';

sub test () {
    return if (!-d FYR_CONF_DIR);
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
    my $n_ready_faxes =
            dbh()->selectrow_array("
                        select count(id) from message
                        where state = 'ready'
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
                            and recipient_email is not null");

    my $time = POSIX::strftime('%H:%M', localtime());

    # Most FYR messages are sent between 0900h and 2200h local time. Check that
    # a message has been submitted within 20 minutes during peak hours or
    # within 2 hours during off hours.
    my $message_threshold = 1200;
    $message_threshold = 7200 if ($time lt '09:00' || $hour gt '22:00');
    
    printf("last message was submitted %d minutes ago", int($last_message_age / 60))
        if ($last_message_age > $message_threshold);
    
    printf("last fax was sent %d minutes ago", int($last_fax_age / 60))
        if ($time ge '08:20' && $hour le '20:00'
            && $n_ready_faxes > 0 && $last_fax_age < 1200);

    printf("last email was sent %d minutes ago", int($last_email_age / 60))
        if ($n_ready_emails > 0 && $last_email_age < 1200);

    # XXX maybe ought to check for messages being confirmed.

    dbh()->disconnect();
}

1;
