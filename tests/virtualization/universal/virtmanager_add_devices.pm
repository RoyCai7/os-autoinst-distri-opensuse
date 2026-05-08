# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test adds some devices to our VMs
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'virt_feature_test_base';
use virt_autotest::common;
use testapi;
use utils;
use version_utils;
use virtmanager;

sub run_test {
    my ($self) = @_;

    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    foreach my $guest (keys %virt_autotest::common::guests) {
        unless ($guest =~ m/hvm/i) {
            record_info "$guest", "VM $guest will get some new devices";

            select_guest($guest);
            detect_login_screen();

            mouse_set(0, 0);
            assert_and_click 'virt-manager_details';
            send_key 'alt-f10';
            assert_and_click 'virt-manager_add-hardware';
            mouse_set(0, 0);
            assert_and_click 'virt-manager_add-storage';
            if (check_screen 'virt-manager_add-storage-ide') {
                assert_and_click 'virt-manager_add-storage-ide';
                assert_and_click 'virt-manager_add-storage-select-xen';
            }
            assert_screen 'virt-manager_add-storage-xen';
            assert_and_click 'virt-manager_add-hardware-finish';
            assert_and_click 'virt-manager_add-hardware';
            mouse_set(0, 0);
            assert_and_click 'virt-manager_add-network';
            send_key 'tab';
            send_key 'tab';
            send_key 'tab';
            send_key 'tab' if is_sle('15-sp2+');    # Details / XML panel
            send_key 'tab' if is_sle('15-sp3+');    # Device name input field
            type_string '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
            save_screenshot();
            assert_and_click 'virt-manager_add-hardware-finish';
            assert_and_click 'virt-manager_disk2';
            assert_screen 'virt-manager_disk2_name';
            assert_and_click 'virt-manager_nic2';

            assert_and_click 'virt-manager_graphical-console';
            send_key 'alt-f10';       # Ensure maximized state before needle matching
            wait_still_screen 2;      # Wait for console rendering to stabilize

            detect_login_screen() if (!check_screen('virt-manager_viewer_disconnected', 5));
            close_guest();
        }
    }

    wait_screen_change { send_key 'ctrl-q'; };
}

1;

