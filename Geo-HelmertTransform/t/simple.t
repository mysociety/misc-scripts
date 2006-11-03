#!/usr/bin/perl -w
#
# simple.t:
# Tests for Geo::HelmertTransform.
#
# $Id: simple.t,v 1.2 2006-11-03 13:39:47 chris Exp $
#

use strict;
use warnings;
use lib 'lib';
use Test::More tests => 4;
use_ok('Geo::HelmertTransform');

#
# This just tests that we can translate a point on the equator in the Airy1830
# datum into WGS84 (not something you'd ever want to do, mind). Should perhaps
# extend with the examples from OS's "Coordinate Systems in Great Britain"
# technical report.
#

my ($lat, $lon, $h) = (0, 0, 0);
my $airy1830 = Geo::HelmertTransform::datum('Airy1830');
my $wgs84    = Geo::HelmertTransform::datum('WGS84');

($lat, $lon, $h)
    = Geo::HelmertTransform::convert_datum($airy1830, $wgs84, $lat, $lon, $h);

is($lat, 0.00480099695040301);
is($lon, -0.000890444825202788);
is($h,   -257.805436616763);
