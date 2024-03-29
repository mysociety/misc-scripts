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
    foreach ("exec_extras", "exec_before_down", "exec_while_down") {
        next unless ref $vhost_conf->{$_} eq 'HASH' && ref $site_conf->{$_} eq 'HASH';
        $conf->{$_} = $site_conf->{$_};
        foreach my $key ( keys %{$vhost_conf->{$_}}) {
            $conf->{$_}{$key} = $vhost_conf->{$_}{$key};
        }
    }

    die "must specify 'servers' in vhost config" if !exists($conf->{servers});
    die "must specify 'staging' in vhost config" if !exists($conf->{staging});
    die "must specify one of 'git_repository' or 'private_git_repository' in vhost config" unless exists($conf->{git_repository}) || exists($conf->{private_git_repository}) || $conf->{redirects_only};

    my $vcspath = '';
    if (exists($conf->{git_repository})) {
        die "must specify 'git_user' in vhost config" if !exists($conf->{git_user});
        die "can't have blank 'git_user', use 'anon' for anonymous" if $conf->{git_user} eq '';
        $conf->{git_ref} = 'origin/master' if !exists($conf->{git_ref});
        $vcspath = $conf->{git_repository};
    }

    if (exists($conf->{private_git_repository})) {
        $conf->{private_git_ref} = 'origin/master' if !exists($conf->{private_git_ref});
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
    $conf->{https_strict_tls} = 0 if !exists($conf->{https_strict_tls});
    $conf->{request_timeout} = '' if !exists($conf->{request_timeout});
    $conf->{ruby_version} = '' if !exists($conf->{ruby_version});
    $conf->{rbenv_global} = 0 if !exists($conf->{rbenv_global});
    $conf->{database_configs} = [];
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
    my $global_settings = read_file($global_settings_file) or die "failed to read /etc/mysociety/config-settings.pl, which is managed by Puppet.";
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
\$https_strict_tls = '$conf->{https_strict_tls}';
\$request_timeout = '$conf->{request_timeout}';
\$randomly = '/data/mysociety/bin/randomly -p 0.5'; # for crontab
\$ruby_version = '$conf->{ruby_version}';
\$rbenv_global = '$conf->{rbenv_global}';
END

    # If there is database config, write it out in the various supported formats.
    if ($conf->{database_configs}) {
        # PHP Config
        print FH "\$database_configs = <<DONE_DATABASE_CONFIGS;\n";
        foreach my $db (@{$conf->{database_configs}}) {
            print FH "define('OPTION_$db->{prefix}_DB_HOST', '$db->{host}');\n";
            print FH "define('OPTION_$db->{prefix}_DB_PORT', $db->{port});\n"              if $db->{port};
            print FH "define('OPTION_$db->{prefix}_DB_RO_HOST', '$db->{replica_host}');\n" if $db->{replica_host};
            print FH "define('OPTION_$db->{prefix}_DB_RO_PORT', $db->{replica_port});\n"   if $db->{replica_port};
            print FH "define('OPTION_$db->{prefix}_DB_NAME', '$db->{name}');\n";
            print FH "define('OPTION_$db->{prefix}_DB_USER', '$db->{username}');\n";
            print FH "define('OPTION_$db->{prefix}_DB_PASS', '$db->{password}');\n";
        }
        print FH "DONE_DATABASE_CONFIGS\n";

        # YAML Config
        print FH "\$database_configs_yml = <<DONE_DATABASE_CONFIGS_YML;\n";
        foreach my $db (@{$conf->{database_configs}}) {
            print FH "$db->{prefix}_DB_HOST: '$db->{host}'\n";
            print FH "$db->{prefix}_DB_PORT: $db->{port}\n"              if $db->{port};
            print FH "$db->{prefix}_DB_RO_HOST: '$db->{replica_host}'\n" if $db->{replica_host};
            print FH "$db->{prefix}_DB_RO_PORT: $db->{replica_port}\n"   if $db->{replica_port};
            print FH "$db->{prefix}_DB_NAME: '$db->{name}'\n";
            print FH "$db->{prefix}_DB_USER: '$db->{username}'\n";
            print FH "$db->{prefix}_DB_PASS: '$db->{password}'\n";
        }
        print FH "DONE_DATABASE_CONFIGS_YML\n";

        # Rails config
        # This doesn't cope with multiple Rails database configs (as you
        # have to list them in the yml file in right place, so one text
        # option can't). If you need to connect to multiple databases from
        # Rails, you'll need to template the configuration using the
        # individual variables generated in the next step.
        if (scalar(@{$conf->{database_configs}}) == 1) {
            my $db = ${$conf->{database_configs}}[0];
            print FH "\$rails_database_config = <<DONE_RAILS_DATABASE_CONFIG;\n";
            print FH "    adapter: $db->{adapter}\n";
            print FH "    database: $db->{name}\n";
            print FH "    username: $db->{username}\n";
            print FH "    password: '$db->{password}'\n";
            print FH "    host: $db->{host}\n";
            print FH "    port: $db->{port}\n";
            print FH "DONE_RAILS_DATABASE_CONFIG\n";
        }

        # Individual Variables for use with arbitrary formats.
        foreach my $db (@{$conf->{database_configs}}) {
            print FH "\$db_config_$db->{prefix}_host = '$db->{host}';\n";
            print FH "\$db_config_$db->{prefix}_port = $db->{port};\n"             if $db->{port};
            print FH "\$db_config_$db->{prefix}_ro_host = '$db->{replica_host}';\n" if $db->{replica_host};
            print FH "\$db_config_$db->{prefix}_ro_port = $db->{replica_port};\n"   if $db->{replica_port};
            print FH "\$db_config_$db->{prefix}_name = '$db->{name}';\n";
            print FH "\$db_config_$db->{prefix}_username = '$db->{username}';\n";
            print FH "\$db_config_$db->{prefix}_password = '$db->{password}';\n";
            print FH "\$db_config_$db->{prefix}_password_escaped = '$db->{password_escaped}';\n";
        }
    }

    print FH "\$cron_host = '" . ${\($conf->{servers}[0] =~ /([^.]+)/)} . "';\n";
    print FH "\$load_balanced_vhost = 1;\n" if $conf->{balancers};
    print FH Dumper($conf->{conf_dir});
    print FH "\$conf_dirs = \$VAR1;\n";
    print FH Dumper($conf->{private_conf_dir});
    print FH "\$private_conf_dirs = \$VAR1;\n";
    print FH "\$admin_dir = '$conf->{admin_dir}';\n" if $conf->{admin_dir};
    print FH "\$admin_group = '$conf->{admin_group}';\n" if $conf->{admin_group};
    print FH "\$admin_uri = '$conf->{admin_uri}';\n" if $conf->{admin_uri};
    print FH "\$internal_access_only = '$conf->{internal_access_only}';\n" if $conf->{internal_access_only};
    print FH "\$prometheus_service_health = '$conf->{prometheus_service_health}';\n" if $conf->{prometheus_service_health};
    print FH Dumper($conf->{public_dirs});
    print FH "\$public_dirs = \$VAR1;\n";
    print FH "\$server_name = '$conf->{server_name}';\n";
    print FH Dumper($conf->{redirects});
    print FH "\$redirects = \$VAR1;\n";
    print FH Dumper($conf->{aliases});
    print FH "\$aliases = \$VAR1;\n";
    if ($conf->{docker}) {
        print FH "# Docker configuration\n";
        print FH Dumper($conf->{docker});
        print FH "\$docker = \$VAR1;\n";
    }
    if ($conf->{balancers}) {
        print FH "# Load Balancers\n";
        print FH Dumper($conf->{balancers});
        print FH "\$balancers = \$VAR1;\n";
    }
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
