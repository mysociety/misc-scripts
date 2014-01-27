#!/usr/bin/perl
#
# Web.pm:
# Test that websites are up.
#
# Nasty because we want to check each host for multihomed site.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Web.pm,v 1.38 2012-01-29 15:07:21 matthew Exp $
#

package Web;

use strict;
use Monitor;

my @pages = qw(
        http://www.mysociety.org/

        http://www.pledgebank.com/
        http://www.pledgebank.com/rights
        http://www.pledgebank.com/faq
	http://pledgebank.barnet.gov.uk/

        http://www.theyworkforyou.com/
        http://www.theyworkforyou.com/mp/tony_blair/sedgefield

        http://www.writetothem.com/
        http://www.writetothem.com/who?pc=CB4+1EP
        http://www.writetothem.com/who?pc=SE26+6SS

        http://www.hearfromyourmp.com/
        http://www.hearfromyourmp.com/league
        http://www.hearfromyourmp.com/view/message/91

        http://www.fixmystreet.com/
        http://www.fixmystreet.com/report/21025

	http://barnet.fixmystreet.com/around?pc=N111NP
        http://southampton.fixmystreet.com/around?pc=S0147LY

        http://scenic.mysociety.org/

        #http://mapumental.channel4.com/signup
        #http://mapumental.channel4.com/tilecache.fcgi/1.0.0/housing/11/1013/663.png

        https://secure.mysociety.org/
    
        http://www.fixmytransport.com/
        http://www.fixmytransport.com/campaigns/provide-non-stepped-access-to-chepst
    
        http://gaze.mysociety.org/gaze?R1%3A0%2C37%3AGaze.get_radius_containing_population%2CL1%3A3%2CT14%3A51.41281945404%2CT17%3A-0.29430381185079%2CT6%3A200000%2C
        http://gaze.mysociety.org/gaze?R1%3A0%2C16%3AGaze.find_places%2CL1%3A5%2CT2%3AGB%2CNT7%3ANewport%2CI2%3A10%2CI1%3A0%2C

	http://propertyscandal.channel4.com/local/
	http://mapit.mysociety.org/postcode/partial/EH1.html

    );
        #http://www.hassleme.co.uk/

# Pages that require non-default response line timeout values
my %timeouts = (
    "http://www.hearfromyourmp.com/league" => 20,
);

sub email() { return 'serious'; }

sub test () {
    return if !mySociety::Config::get('RUN_EXTRA_SERVERS_TESTS');
    foreach my $page (@pages) {
        next if $page =~ /^#/;
        
        if (exists $timeouts{$page}) {
            Monitor::test_web($page, $timeouts{$page});
        } else {
            Monitor::test_web($page);
        }
    }
}

1;
