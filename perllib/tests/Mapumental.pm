#!/usr/bin/perl
#
# Mapumental.pm:
# Check that demo daemon is running.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Mapumental.pm,v 1.1 2011-08-18 09:18:48 matthew Exp $

package Mapumental;

use strict;

use constant COL_CONF_DIR => '/data/vhost/mapumental.channel4.com/mysociety/iso/conf';

sub email() { return 'mapumental'; }

sub test () {
    return if (!-d COL_CONF_DIR || !-e COL_CONF_DIR . "/general");
    my @procs = map { chomp; $_ } `ps ax -o user:20,command |grep isodaemon|grep -v grep|cut -d" " -f 1|sort|uniq`;
    unless (scalar @procs == 1 && $procs[0] eq 'col') {
        print "isodaemon is not running on arrow\n";
    }
}

1;
