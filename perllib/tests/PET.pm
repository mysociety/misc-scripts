#!/usr/bin/perl
#
# PET.pm:
# Check that petitions are working (up to a point).
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PET.pm,v 1.8 2011-01-25 15:41:54 matthew Exp $
#

package PET;

use strict;

use POSIX qw();
use Data::Dumper;

use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::ArrayUtils;

use constant PET_CONF_DIR => '/data/vhost/petitions.number10.gov.uk/petitions/conf';

sub email() { return 'cron-petitions'; }

sub test_procs($@) {
    my ($thing, @vhosts) = @_;
    my @pets = map { chomp; $_ } `ps ax -o user:20,command |grep $thing|cut -d" " -f 1|sort|uniq`;
    my $diff = mySociety::ArrayUtils::symmetric_diff(\@pets, \@vhosts);
    if (@$diff) {
        print "$thing running and daemons listed differ - difference is:\n";
        print Dumper $diff;
    }
}

sub test () {
    return if (!-d PET_CONF_DIR || !-e PET_CONF_DIR . "/general");

    our ($vhosts, $sites);
    require "/data/servers/vhosts.pl";

    # Check all the daemons are running
    my @vhosts;
    foreach (values %$vhosts) {
        next unless $_->{site} eq 'petitions' && $_->{daemons} && grep { /^petemaild/ } keys %{$_->{daemons}};
        my $user = $_->{user} || $sites->{$_->{site}}->{user};
        push @vhosts, $user;
    }
    test_procs('petemaild', @vhosts);
    test_procs('petsignupd', @vhosts);

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

    return if mySociety::Config::get('SIGNING_DISABLED');

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
                        where emailsent = \'confirmed\'
                        order by signtime desc
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
