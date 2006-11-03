#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use Test::More tests => 4;
use_ok('Geo::HelmertTransform');

my ( $lat, $lon, $h ) = ( 0, 0, 0 );
my $airy1830 = Geo::HelmertTransform::datum('Airy1830');
my $wgs84    = Geo::HelmertTransform::datum('WGS84');

( $lat, $lon, $h )
    = Geo::HelmertTransform::convert_datum( $airy1830, $wgs84, $lat, $lon,
    $h );

is( $lat, 0.00480099695040301 );
is( $lon, -0.000890444825202788 );
is( $h,   -257.805436616763 );
