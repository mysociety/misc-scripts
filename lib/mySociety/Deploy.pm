package mySociety::Deploy;

use Data::Dumper;
use File::Basename;
use File::Slurp;

sub server_name {
    my $conf = shift;
    my $vhost = $conf->{vhost};

    my $server_name = $vhost;
    my $aliases = $conf->{aliases};
    my %redirects = map { $_ => 1 } @{ $conf->{redirects} };
    if ($redirects{$vhost}) {
        # We want to redirect the name used for the vhost.
        die "Redirect for '$vhost' requires alias to be present" unless @$aliases;
        die "Alias '$aliases->[0]' must not match vhost '$vhost'" if $aliases->[0] eq $vhost;
        $server_name = shift @$aliases;
    }
    return $server_name;
}

sub write_settings_file {
    my ($settings_file, $conf) = @_;
    my $settings_file_namepart = basename($settings_file);

    $conf->{vhost} =~ m/^([^.]+)\.(.*)$/;
    my $vhost_first = $1;
    my $vhost_rest = $2;

    my $global_settings_file = "/etc/mysociety/config-settings.pl";
    my $global_settings = read_file($global_settings_file) or die "failed to read /etc/mysociety/config-settings.pl, which is made by deploy-configuration";
    my $old_umask = umask(0077);
    open(FH, ">", $settings_file) or die "failed to open $settings_file for write";
    print FH <<END;
#
# $settings_file_namepart
#

\$site = '$conf->{site}';
\$vhost = '$conf->{vhost}';
\$vhost_dir = '$conf->{vhost_dir}';
\$vcspath = '$conf->{vcspath}';
\$site = '$conf->{site}';
\$staging = '$conf->{'staging'}';
\$vhost_first = '$vhost_first';
\$vhost_rest = '$vhost_rest';
\$user = '$conf->{user}';
\$group = '$conf->{group}';
\$wildcard_vhost = '$conf->{'wildcard_vhost'}';
\$https = '$conf->{'https'}';
\$https_only = '$conf->{'https_only'}';
\$balancer = '$conf->{'balancer'}';
\$ipv4addr = '$conf->{'ipv4addr'}';
\$ipv6addr = '$conf->{'ipv6addr'}';
\$fastcgi = '$conf->{'fastcgi'}';
\$request_timeout = '$conf->{'request_timeout'}';
\$randomly = '/data/mysociety/bin/randomly -p 0.5'; # for crontab
\$database_configs = <<DONE_DATABASE_CONFIGS;
$conf->{database_configs}{default}
DONE_DATABASE_CONFIGS
\$database_configs_yml = <<DONE_DATABASE_CONFIGS_YML;
$conf->{database_configs}{yaml}
DONE_DATABASE_CONFIGS_YML
\$rails_database_config = <<DONE_RAILS_DATABASE_CONFIG;
$conf->{database_configs}{rails}
DONE_RAILS_DATABASE_CONFIG
\$external_database_configs = <<DONE_EXTERNAL_DATABASE_CONFIGS;
$conf->{database_configs}{external}
DONE_EXTERNAL_DATABASE_CONFIGS
\$external_database_configs_yml = <<DONE_EXTERNAL_DATABASE_CONFIGS_YML;
$conf->{database_configs}{external_yaml}
DONE_EXTERNAL_DATABASE_CONFIGS_YML
END

    print FH Dumper($conf->{conf_dir});
    print FH "\$conf_dirs = \$VAR1;\n";
    print FH Dumper($conf->{private_conf_dir});
    print FH "\$private_conf_dirs = \$VAR1;\n";
    print FH "\$admin_dir = '$conf->{'admin_dir'}';\n" if $conf->{'admin_dir'};
    print FH "\$admin_group = '$conf->{'admin_group'}';\n" if $conf->{'admin_group'};
    print FH "\$admin_uri = '$conf->{'admin_uri'}';\n" if $conf->{'admin_uri'};
    print FH "\$internal_access_only = '$conf->{'internal_access_only'}';\n" if $conf->{'internal_access_only'};
    print FH Dumper($conf->{'public_dirs'});
    print FH "\$public_dirs = \$VAR1;\n";
    print FH "\$server_name = '$conf->{server_name}';\n";
    print FH Dumper($conf->{'redirects'});
    print FH "\$redirects = \$VAR1;\n";
    print FH Dumper($aliases);
    print FH "\$aliases = \$VAR1;\n";
    print FH <<END;

# ---------------------------------------------------------
# Settings from here on are copied from:
# $global_settings_file

$global_settings
END
    close FH;
    chown($conf->{user_uid}, $conf->{user_gid}, $settings_file);
    umask($old_umask);
}

1;
