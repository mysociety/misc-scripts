#!/usr/bin/perl
#
# PostgreSQL.pm:
# Check can connect to PostgreSQL database, and there are no stale processes.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PostgreSQL.pm,v 1.22 2010-10-08 15:46:54 matthew Exp $
#

package PostgreSQL;

use strict;

use DBI;
use Data::Dumper;

my $SERVERCLASSFILE="/data/servers/serverclass";
my $MACHINECONFIGDIR="/data/servers/machines/";
my $debian_version="";

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
        next if $current_query =~ m/$exceptions/; 
        print "PostgreSQL query taking more than $age; server:$postgresql_server; database:$datname; user:$usename; process: $procpid; query:$current_query\n";
    }
}

sub email() { return 'sysadmin'; }

sub test() {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');

    my $port;

    open(SERVERFILE, '<', $SERVERCLASSFILE ) or die ("Cannot open $SERVERCLASSFILE : $!");
    my @postgresql_servers = map {/^(\w+)/} grep {!/^#/ && /\bdatabase\b/} <SERVERFILE>;
    close(SERVERFILE);

    my $user = mySociety::Config::get('MONITOR_PSQL_USER');
    my $pass = mySociety::Config::get('MONITOR_PSQL_PASS');
    foreach my $server (@postgresql_servers) {
        # Get machine OS version
        open(MACHINEFILE, '<', $MACHINECONFIGDIR . $server . ".pl") or die ("Cannot open $MACHINECONFIGDIR : $!") ;
        my @debian_version = grep {/\$debian_version/} <MACHINEFILE>;
        my ($key, $version)  = split("\"", $debian_version[0]);
        close(MACHINEFILE);

        if($version eq "lenny") {
            $port = 5434
        } else {
            $port = 5433
        }

        my $postgresql_server = $server . ".int.ukcod.org.uk";
        # Connect to database
        my $dbh = DBI->connect("dbi:Pg:dbname=template1;host=$postgresql_server;port=$port", $user, $pass);
        if ( !defined $dbh ) {
            print "Cannot connect to database on $postgresql_server:$port as $user\n";
            next;
        } 

        # Check for long running queries
        # ... check most queries take less than 30 minutes, with some exceptions 
        # * petitions delete from signer - for large petitions it just does take ages
        # * WhatDoTheyKnow backing up the raw_emails table - which is large
        check_old_queries($dbh, "30 minutes", "(^delete from signer|^COPY public.raw_emails )", $postgresql_server, $port, $user); 
        # .. show anything more than 12 hours long ($^ will never match, so no exceptions)
        check_old_queries($dbh, "12 hours", "\$^", $postgresql_server, $port, $user); 

        $dbh->disconnect;
    }
}

1;
