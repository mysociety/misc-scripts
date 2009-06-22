#!/usr/bin/perl
#
# PostgreSQL.pm:
# Check can connect to PostgreSQL database, and there are no stale processes.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PostgreSQL.pm,v 1.16 2009-06-22 10:52:47 francis Exp $
#

package PostgreSQL;

use strict;

use DBI;

# XXX this ought to check vhosts.pl or the serverclass to work out which databases to check
my @postgresql_servers = qw(tea.int.ukcod.org.uk bitter.int.ukcod.org.uk steak.int.ukcod.org.uk cake.int.ukcod.org.uk sandwich.int.ukcod.org.uk pudding.int.ukcod.org.uk stilton.int.ukcod.org.uk);
my $postgresql_port = 5433;

sub check_old_queries($$$$$$) {
    my ($dbh, $age, $exceptions, $postgresql_server, $postgresql_port, $user) = @_;

    # Find active queries which are old
    my $sth = $dbh->prepare("select datname, usename, current_query, query_start, procpid from pg_stat_activity where current_query not like '<IDLE>%' and query_start < now() - '$age'::interval order by query_start");
    if ( !defined $sth ) {
        print "Cannot prepare statement on $postgresql_server:$postgresql_port as $user: $DBI::errstr\n";
        next;
    }
    $sth->execute;
    while ( my ($datname, $usename, $current_query, $query_start, $procpid) = $sth->fetchrow()) {
        # some exceptions for particular queries
        next if $current_query =~ m/$exceptions/; # for large petitions this does take ages
        print "PostgreSQL query taking more than $age; server:$postgresql_server; database:$datname; user:$usename; process: $procpid; query:$current_query\n";
    }
}

sub test() {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');

    my $user = mySociety::Config::get('MONITOR_PSQL_USER');
    my $pass = mySociety::Config::get('MONITOR_PSQL_PASS');
    foreach my $postgresql_server (@postgresql_servers) {
        # Connect to database
        my $port = $postgresql_port;
        $port = 5432 if $postgresql_server eq 'bitter.int.ukcod.org.uk'; # bitter has old PG database
        $port = 5434 if $postgresql_server eq 'stilton.int.ukcod.org.uk' || $postgresql_server eq 'marmite.int.ukcod.org.uk'; # stilton/marmite on new
        my $dbh = DBI->connect("dbi:Pg:dbname=template1;host=$postgresql_server;port=$port", $user, $pass);
        if ( !defined $dbh ) {
            print "Cannot connect to database on $postgresql_server:$postgresql_port as $user\n";
            next;
        } 

        # Check for long running queries
        # ... check most queries take less than 30 minutes, with some exceptions (petitions delete from signer)
        check_old_queries($dbh, "30 minutes", "\$(delete from signer)", $postgresql_server, $postgresql_port, $user); 
        # .. show anything more than 12 hours long
        check_old_queries($dbh, "12 hours", "\$^", $postgresql_server, $postgresql_port, $user); 

        $dbh->disconnect;
    }
}

1;
