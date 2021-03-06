#!/usr/bin/perl -w
#
# compareconfig.pl:
# Compare two configuration files.
#
# Compares the two config files given on the command line, and displays keys
# which are present in one but not the other. Exits successfully if there are
# no differences.

use strict;
use FindBin;
use lib "$FindBin::Bin/../perllib";

use mySociety::Config;

# compare_one_way A B
# A and B are references-to-hashes returned by mySociety::Config::read_config;
# this function warns on cases where a key is present only in A. Returns the
# number of such keys.
sub compare_one_way {
    my ($a, $b) = @_;
    my $n = 0;

    foreach my $key (keys %$a) {
        if (!exists $b->{$key}) {
            print STDERR $b->{'CONFIG_FILE_NAME'} . " does not contain $key, " . $a->{'CONFIG_FILE_NAME'} . " does\n";
            ++$n;
        }
    }
    return $n;
}

die "Specify two config files as parameters" unless (@ARGV == 2);

my $a = mySociety::Config::read_config($ARGV[0]);
my $b = mySociety::Config::read_config($ARGV[1]);

my $error = 0;
$error += compare_one_way($a, $b);
$error += compare_one_way($b, $a);

$error = 127 if ($error > 127); # limited range of exit codes

exit($error);
