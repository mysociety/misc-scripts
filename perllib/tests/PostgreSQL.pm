#!/usr/bin/perl
#
# PostgreSQL.pm:
# Check can connect to PostgreSQL database, and there are no stale processes.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PostgreSQL.pm,v 1.7 2006-08-24 22:53:27 francis Exp $
#

package PostgreSQL;

use strict;

use DBI;

my @postgresql_servers = qw(svcs.tea.int.ukcod.org.uk svcs.bitter.int.ukcod.org.uk);
my $postgresql_port = 5432;

sub test() {
    my $user = mySociety::Config::get('MONITOR_PSQL_USER');
    my $pass = mySociety::Config::get('MONITOR_PSQL_PASS');
    foreach my $postgresql_server (@postgresql_servers) {

        # Connect to database
        my $dbh = DBI->connect("dbi:Pg:dbname=template1;host=$postgresql_server;port=$postgresql_port", $user, $pass);
        if ( !defined $dbh ) {
            print "Cannot connect to database on $postgresql_server:$postgresql_port as $user\n";
            next;
        } 

        # Find active queries which are old
        my $sth = $dbh->prepare("select datname, usename, current_query, query_start, procpid from pg_stat_activity where current_query not like '<IDLE>%' and query_start < now() - '30 minutes'::interval order by query_start");
        if ( !defined $sth ) {
            print "Cannot prepare statement on $postgresql_server:$postgresql_port as $user: $DBI::errstr\n";
            next;
        }
        $sth->execute;
        while ( my ($datname, $usename, $current_query, $query_start, $procpid) = $sth->fetchrow()) {
            print "PostgreSQL query taking more than 30 minutes; server:$postgresql_server; database:$datname; user:$usename; process: $procpid; query:$current_query\n";
        }
        $dbh->disconnect;
    }
}

1;
