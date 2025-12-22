# SUSE openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: SUSEConnect
# Summary: Register system image against SCC
# Maintainer: qac <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use registration qw(verify_scc investigate_log_empty_license runtime_registration);
use backend::console_proxy;

# Recover serial console after Hyper-V snapshot restore
# Serial console may become unresponsive after VM snapshot restore on Hyper-V
sub recover_serial_console_hyperv {
    return unless check_var('HYPERV', '1') || check_var('VIRSH_VMM_FAMILY', 'hyperv');

    # Test if serial console is responsive
    my $serial_ok = eval {
        script_run('true', timeout => 10);
        1;
    };

    return if $serial_ok;

    record_info('Serial Recovery', 'Serial console unresponsive after snapshot restore, attempting recovery...');

    # Use VNC/graphical console to restart serial service
    select_console('root-console');
    enter_cmd('systemctl restart serial-getty@ttyS0.service');
    sleep 5;

    # Re-select serial terminal
    select_console('root-console');
}

sub run {
    recover_serial_console_hyperv();
    runtime_registration();    # assume it will run in serial terminal
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license unless (script_run 'test -f /var/log/YaST2/y2log');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
