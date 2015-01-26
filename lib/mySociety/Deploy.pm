package mySociety::Deploy;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Slurp;

# Read in configuration file
our ($vhosts, $sites, $databases);

sub read_conf {
    my $servers_dir = shift;
    require "$servers_dir/vhosts.pl";
}

sub setup_conf {
    my ($vhost) = @_;

    my $hostname = `hostname`;
    chomp($hostname);

    my $vhost_conf = $vhosts->{$vhost};
    die "vhost '$vhost' is not in vhosts.pl" if !$vhost_conf;
    my $site = $vhost_conf->{site};
    die "site not specified for '$vhost' in vhosts.pl" if !$site;
    my $site_conf = $sites->{$site};
    die "site '$site' is not in vhosts.pl" if !$site_conf;

    my $conf = {
        vhost => $vhost,
        vhost_dir => "/data/vhost/$vhost",
    };

    # Merge vhost and site configs together
    foreach my $key ( keys %$site_conf ) { $conf->{$key} = $site_conf->{$key}; }
    foreach my $key ( keys %$vhost_conf ) { $conf->{$key} = $vhost_conf->{$key}; }

    die "must specify 'servers' in vhost config" if !exists($conf->{servers});
    die "must specify 'staging' in vhost config" if !exists($conf->{staging});
    die "must specify one of 'git_repository' or 'private_git_repository' in vhost config" unless exists($conf->{git_repository}) || exists($conf->{private_git_repository}) || $conf->{redirects_only};

    my $vcspath = '';
    if (exists($conf->{git_repository})) {
        die "must specify 'git_user' in vhost config" if !exists($conf->{git_user});
        die "can't have blank 'git_user', use 'anon' for anonymous" if $conf->{git_user} eq '';
        if (exists($conf->{git_ref_server_mapping})) {
            die "git_ref_server_mapping defined, but no mapping for $hostname"
                if !exists($conf->{git_ref_server_mapping}{$hostname});
            $conf->{git_ref} = $conf->{git_ref_server_mapping}{$hostname};
        } elsif (!exists($conf->{git_ref})) {
            $conf->{git_ref} = 'origin/master';
        }
        $vcspath = $conf->{git_repository};
    }

    if (exists($conf->{private_git_repository})) {
        if (exists($conf->{private_git_ref_server_mapping})) {
            die "private_git_ref_server_mapping defined, but no mapping for $hostname"
                if !exists($conf->{private_git_ref_server_mapping}{$hostname});
            $conf->{private_git_ref} = $conf->{private_git_ref_server_mapping}{$hostname};
        } elsif (!exists($conf->{private_git_ref})) {
            $conf->{private_git_ref} = 'origin/master' if !exists($conf->{private_git_ref});
        }
        $vcspath = $conf->{private_git_repository} if !$vcspath;
    }
    $conf->{vcspath} = $vcspath;

    # Check if we should be deploying to a timestamped directory which
    # is then symlinked into place.
    if ($conf->{timestamped_deploy}) {
        if (exists($conf->{git_repository}) && exists($conf->{private_git_repository})) {
            die "For a timestamped deploy you can only specify one of git_repository and private_git_repository";
        }
        if (exists($conf->{private_git_dirs})) {
            die "You can't use private_git_dirs with the timestamped_deploy option";
        }

        # With timestamped_deploy, we use different options to specify hooks
        # that are run on deploy.
        if ($conf->{exec_extras}) {
            die "exec_extras cannot be used with timestamped_deploy";
        }
    } else {
        foreach ("exec_before_down", "exec_while_down") {
            if ($conf->{$_}) {
                die "You cannot use $_ without timestamped_deploy";
            }
        }
    }

    my ($user_login, $user_pass, $user_uid, $user_gid,
        $user_quota, $user_comment,
        $user_real_name, $user_home_dir, $user_shell,
        $user_expire) = getpwnam($conf->{user});
    die "Unknown user '$conf->{user}'" if !$user_uid;
    die "Unknown group for user '$conf->{user}'" if !$user_gid;
    $conf->{user_uid} = $user_uid;
    $conf->{user_gid} = $user_gid;
    $conf->{group} = getgrgid($user_gid);

    # Deal with redirecting the vhost itself
    $conf->{server_name} = mySociety::Deploy::server_name($conf);

    $conf->{wildcard_vhost} = 0 if !exists($conf->{wildcard_vhost});
    $conf->{https} = 0 if !exists($conf->{https});
    $conf->{https_only} = 0 if !exists($conf->{https_only});
    $conf->{fastcgi} = 1 if !exists($conf->{fastcgi});
    $conf->{balancer} = '' if !exists($conf->{balancer});
    $conf->{ipv4addr} = '' if !exists($conf->{ipv4addr});
    $conf->{ipv6addr} = '' if !exists($conf->{ipv6addr});
    $conf->{request_timeout} = '' if !exists($conf->{request_timeout});
    $conf->{database_configs} = {
        default => '',
        external => '',
        yaml => '',
        external_yaml => '',
        rails => '',
    };
    return $conf;
}

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
\$staging = '$conf->{staging}';
\$vhost_first = '$vhost_first';
\$vhost_rest = '$vhost_rest';
\$user = '$conf->{user}';
\$group = '$conf->{group}';
\$wildcard_vhost = '$conf->{wildcard_vhost}';
\$https = '$conf->{https}';
\$https_only = '$conf->{https_only}';
\$balancer = '$conf->{balancer}';
\$ipv4addr = '$conf->{ipv4addr}';
\$ipv6addr = '$conf->{ipv6addr}';
\$fastcgi = '$conf->{fastcgi}';
\$request_timeout = '$conf->{request_timeout}';
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
    print FH "\$admin_dir = '$conf->{admin_dir}';\n" if $conf->{admin_dir};
    print FH "\$admin_group = '$conf->{admin_group}';\n" if $conf->{admin_group};
    print FH "\$admin_uri = '$conf->{admin_uri}';\n" if $conf->{admin_uri};
    print FH "\$internal_access_only = '$conf->{internal_access_only}';\n" if $conf->{internal_access_only};
    print FH Dumper($conf->{public_dirs});
    print FH "\$public_dirs = \$VAR1;\n";
    print FH "\$server_name = '$conf->{server_name}';\n";
    print FH Dumper($conf->{redirects});
    print FH "\$redirects = \$VAR1;\n";
    print FH Dumper($conf->{aliases});
    print FH "\$aliases = \$VAR1;\n";
    print FH <<END;

# ---------------------------------------------------------
# Settings from here on are copied from:
# $global_settings_file

$global_settings
END
    close FH;
    chown($conf->{user_uid}, $conf->{user_gid}, $settings_file) unless ref $settings_file;
    umask($old_umask);
}

1;
