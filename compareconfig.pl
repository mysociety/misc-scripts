#!/usr/bin/perl -w -I../perllib

# Script to compare two mySociety config files and give an error
# if they don't contain exactly the same keys.

use mySociety::Config;
use Data::Dumper;

die "Specify two config files as parameters" unless $#ARGV == 1;

my $a = mySociety::Config::read_config($ARGV[0]);
my $b = mySociety::Config::read_config($ARGV[1]);

our $error = 0;

sub compare_one_way {
    ($a, $b) = @_;

    foreach my $key (keys %$a) {
        if (!defined $b->{$key}) {
            print $b->{'CONFIG_FILE_NAME'} . " does not contain $key, " . $a->{'CONFIG_FILE_NAME'} . "does\n";
            $::error = 1;
        }
    }
}

compare_one_way($a, $b);
compare_one_way($b, $a);

exit $error;
