#!/usr/bin/perl
#
# File.pm:
# Test that we can create a file in various useful places.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: File.pm,v 1.3 2007-01-23 15:14:15 francis Exp $
#

package File;

use strict;

use Errno;
use IO::File;
use Time::HiRes qw(time);

use constant TEST_FILE_SIZE => 65536;
use constant MAX_WRITE_TIME => 2;

sub test () {
    # Form list of directories to test from list of mounted file systems.
    my $f = new IO::File("/etc/mtab", O_RDONLY);
    if (!$f) {
        print "/etc/mtab: open: $!\n";
        return;
    }
    my @dirs;
    while (my $line = $f->getline()) {
        chomp($line);
        my ($dev, $mnt, $type, $flags, $a, $b) = split(/\s+/, $line);
        # Exclude filesystems to which we wouldn't expect to be able to write.
        push(@dirs, $mnt) unless ($type =~ /^(proc|devpts|usbfs|sysfs)$/);
    }
    if ($f->error()) {
        print "/etc/mtab: read: $!\n";
    }
    $f->close();
    foreach my $dir (@dirs) {
        next unless (-d $dir);
        my ($name, $f, $i);
        for ($i = 0; $i < 10; ++$i) {
            $name = sprintf('%s/.monitor-test.%d.%d.%08x', $dir, $$, time(), rand(0xfffffff));
            $f = new IO::File($name, O_RDWR | O_CREAT | O_EXCL, 0600);
            if (!$f && !$!{EEXIST}) {
                print "$dir: unable to create file: $!\n";
                goto end;
            } elsif ($f) {
                last;
            }
        }

        if (!$f) {
            print "$dir: $i attempts to create test file failed with EEXIST\n";
            goto end;
        }

        # Generate random buffer, write it to disk, read it back and check it's
        # the same.
        my $buf = '';
        my $size = TEST_FILE_SIZE;
        while (length($buf) < $size) {
            $buf .= pack('L', int(rand(0xffffffff)));
        }

        my $t1 = time();

        my $off = 0;
        while ($off < length($buf)) {
            my $n = $f->syswrite($buf, length($buf) - $off, $off);
            if (!defined($n)) {
                print "$dir: write to test file (after $off / $size bytes): $!\n";
                goto end;
            }
            $off += $n;
        }

        if (!$f->sync()) {
            print "$dir: fsync on test file: $!\n";
            goto end;
        }

        my $t2 = time();
        if (($t2 - $t1) > MAX_WRITE_TIME) {
            printf "%s: write+sync of %d bytes took %.2fs (> %.2fs)\n",
                    $dir, $size, $t2 - $t1, MAX_WRITE_TIME;
        }

        $f->seek(0, SEEK_SET);

        my $buf2 = '';
        $off = 0;
        while ($off < length($buf)) {
            my $n = $f->sysread($buf2, length($buf) - $off, $off);
            if (!defined($n)) {
                print "$dir: read from test file (after $off / $size bytes) : $!\n";
                goto end;
            } elsif ($n == 0) {
                print "$dir: premature EOF reading from test file (after $off / $size bytes)\n";
                goto end;
            }
            $off += $n;
        }

        if ($buf ne $buf2) {
            print "$dir: data read back from test file differ from data written\n";
            goto end;
        }
        
end:
        $f->close() if ($f);
        unlink($name) if ($name);
    }
}

1;
