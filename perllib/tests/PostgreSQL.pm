#!/usr/bin/perl
#
# PostgreSQL.pm:
# Check can connect to PostgreSQL database, and there are no stale processes.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PostgreSQL.pm,v 1.1 2006-04-02 01:29:01 francis Exp $
#

package PostgreSQL;

use strict;

use DBI;

sub test() {
    my $host = mySociety::Config::get('DB_HOST');
    my $port = mySociety::Config::get('DB_PORT');
    my $user = mySociety::Config::get('DB_USER');
    my $pass = mySociety::Config::get('DB_PASS');

    # Connect to database
    my $dbh = DBI->connect("dbi:Pg:host=$host;port=$port", $user, $pass);
    if ( !defined $dbh ) {
        print "Cannot connect to database on $host:$port as $user\n";
        return;
    } 

    # Find active queries which are old
    my $sth = $dbh->prepare("select datname, usename, current_query, query_start from pg_stat_activity where current_query not like '<IDLE>%' and query_start < now() - '30 minutes'::interval order by query_start");
    if ( !defined $sth ) {
        print "Cannot prepare statement: $DBI::errstr\n";
        return;
    }
    $sth->execute;
    while ( my ($datname, $usename, $current_query, $query_start) = $sth->fetchrow()) {
        print "PostgreSQL query on $datname taking more than 30 minutes: $current_query\n";
    }
}

1;
