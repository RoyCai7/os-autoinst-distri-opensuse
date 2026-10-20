# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Install and verify UPDATE_PACKAGE on a transactional host
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use transactional;

sub get_target_package {
    my $package = get_var('UPDATE_PACKAGE', '');

    if (!$package) {
        my $build = get_required_var('BUILD');
        return '' if $build =~ /none/i;
        die "BUILD value is $build, but does not match required format" unless $build =~ /:\d+:([^:]+)$/;
        $package = $1;
    }

    return '' if $package =~ /none/i;
    return $package if $package =~ /qemu|virt-manager|libguestfs|open-vm-tools|snphost|dnsmasq|snpguest/;
    return 'libvirt-client' if $package =~ /libvirt/;
    return 'libslirp0' if $package =~ /libslirp/;
    die "Xen package updates are not supported on SLE 16" if $package =~ /xen/;
    return 'kernel-default';
}

sub check_package {
    my ($package) = @_;
    my ($installed, $from_test_repo);

    transactional::enter_trup_shell(global_options => '--drop-if-no-change');
    $installed = script_run("rpm -q $package") == 0;
    $from_test_repo = script_run("zypper if $package | grep -qE 'Repository.*TEST_[0-9]+'") == 0;
    transactional::exit_trup_shell;

    return ($installed, $from_test_repo);
}

sub install_package {
    my ($package) = @_;

    transactional::trup_call("pkg install $package", timeout => 1200);
    transactional::reboot_on_changes();
}

sub update_host_from_staging {
    transactional::enter_trup_shell(global_options => '--drop-if-no-change');
    zypper_call('--gpg-auto-import-keys up', exitcode => [0, 102, 103], timeout => 1200);
    transactional::exit_trup_shell_and_reboot();
}

sub run {
    shift;
    select_serial_terminal;

    my $target_package = get_target_package();
    unless ($target_package) {
        record_info('Skip Package Install', 'No target package specified or BUILD indicates no package update');
        return;
    }

    update_host_from_staging();

    record_info('Package Install Check', "Checking and installing transactional host package: $target_package");
    my ($is_installed, $from_test_repo) = check_package($target_package);

    unless ($is_installed && $from_test_repo) {
        record_info('Installing Package', "Installing $target_package from TEST repository in a new snapshot");
        install_package($target_package);
    }

    transactional::enter_trup_shell(global_options => '--drop-if-no-change');
    my $version = script_output("rpm -q $target_package");
    validate_script_output("zypper if $target_package", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
    transactional::exit_trup_shell;

    record_info('Package Validated', "$target_package is installed from a TEST repository and up-to-date: $version");
}

sub test_flags {
    return {fatal => 1};
}

1;