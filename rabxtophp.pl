#!/usr/bin/perl -w -I ../perllib/
#
# rabxtophp.pl:
# Reads perldoc from a Perl class implementing a RABX interface, and produces a
# PHP include file for talking to that RABX interface.
#

my $rcsid = ''; $rcsid .= '$Id: rabxtophp.pl,v 1.6 2005-11-25 16:27:12 francis Exp $';

use strict;

use Pod::POM;
use Data::Dumper;
use Pod::POM::View::Text;

use mySociety::StringUtils qw(trim);

my $perl_source = $ARGV[0];
die "Give source .pm file as first parameter" unless defined($perl_source);
my $main_include_path = $ARGV[1];
die "Give relative path to mysociety/phplib" unless defined($main_include_path);

my $parser = Pod::POM->new( { warn => 1} );
my $view = 'Pod::POM::View::Text';

# parse from a text string
my $pom = $parser->parse_file($perl_source) || die $parser->error();

# find items representing functions and display them
my ($rabx_namespace, $php_namespace, $conf_name);
sub process_functions {
    my $parent = shift;
    foreach my $content ($parent->content()) {
        if ($content->type() eq 'head2' or $content->type() eq 'over') {
            # Recurse through head2 or over
            process_functions($content)
        }  elsif ($content->type() eq 'item') {
            # Display function item as PHP.
            # Find parameters and function name
            my @params = split /\s+/, $content->title();
            my $function_name = shift @params;
            # Print the help comment
            my $comment = $view->view_item($content);
            $comment =~ s/$function_name/${php_namespace}_$function_name/g;
            chomp $comment;
            chomp $comment;
            print "/$comment */\n";
            # Create list of PHP variables with defaults for optional params
            my $optional = 0;
            my @opt_args;
            my @call_args;
            do {
                my $param = $_;
                next if $param eq "..."; # func_get_args and PHPs flexible syntax covers this
                $optional = 1 if $param =~ m/\[/;
                my $without_optmarks = $param;
                $without_optmarks =~ s/[\[\]]//g;
                push @opt_args, "\$" . lc($without_optmarks) . ($optional ? " = null" : ""); 
                push @call_args, "\$" . lc($without_optmarks);
                $optional = 0 if $param =~ m/\]/;
            } foreach @params;
            my $opt_list = join(", ", @opt_args);
            my $call_list = join(", ", @call_args);
            # Print out PHP function
            print <<END;
function ${php_namespace}_$function_name($opt_list) {
    global \$${php_namespace}_client;
    \$params = func_get_args();
    \$result = \$${php_namespace}_client->call('${rabx_namespace}.${function_name}', \$params);
    return \$result;
}

END
        }
    }
}

sub process_constants {
    my $parent = shift;
    foreach my $content ($parent->content()) {
        if ($content->type() eq 'head2' or $content->type() eq 'over') {
            # Recurse through head2 or over
            process_constants($content)
        } elsif ($content->type() eq 'item') {
            my ($constant, $value) = split /\s+/, $content->title();
            my $comment = $view->view_item($content);
            $comment =~ s/\* $constant $value//gs;
            $comment =~ s/\n/ /g;
            $comment =~ s/\s$//gs;
            $comment =~ s/^\s//gs;
            print "define('${conf_name}_$constant', $value);        /* $comment */\n";
        }
    }
}


# find info
my $description;
foreach my $head1 ($pom->head1()) {
    if ($head1->title() eq "DESCRIPTION") {
        $description = trim($view->view_text($head1));
        $description =~ s/Implementation of/Client interface for/;
    }
    if ($head1->title() eq "NAME") {
        $rabx_namespace = trim($view->view_text($head1));
        if ($rabx_namespace eq 'FYR.Queue') {
            $php_namespace = 'msg';
            $conf_name = 'FYR_QUEUE';
        } else {
            $php_namespace = lc $rabx_namespace;
            $conf_name = uc $rabx_namespace;
        }
    }
}
die "Need DESCRIPTION section in perldoc" if !$description;
die "Need NAME section in perldoc" if !$rabx_namespace;

# Print header
print <<END;
<?php
/* 
 * THIS FILE WAS AUTOMATICALLY GENERATED BY $0, DO NOT EDIT DIRECTLY
 * 
 * ${php_namespace}.php:
 * $description
 *
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * WWW: http://www.mysociety.org
 *
 * $rcsid
 *
 */

require_once('${main_include_path}rabx.php');

/* ${php_namespace}_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function ${php_namespace}_get_error(\$e) {
    if (!rabx_is_error(\$e))
        return FALSE;
    else
        return \$e->text;
}

/* ${php_namespace}_check_error R
 * If R indicates failure, displays error message and stops procesing. */
function ${php_namespace}_check_error(\$data) {
    if (\$error_message = ${php_namespace}_get_error(\$data))
        err(\$error_message);
}

\$${php_namespace}_client = new RABX_Client(OPTION_${conf_name}_URL);

END

# find the functions
foreach my $head1 ($pom->head1()) {
    if ($head1->title() eq "FUNCTIONS") {
        process_functions($head1);
    } elsif ($head1->title() eq "CONSTANTS") {
        process_constants($head1);
        print "\n";
    }
}

# print footer
print <<END;

?>
END

