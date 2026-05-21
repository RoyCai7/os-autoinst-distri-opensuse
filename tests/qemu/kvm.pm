# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run QEMU using KVM
# Maintainer: Dominik Heidler <dheidler@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use Utils::Architectures;
use utils;


sub run {
    select_console 'root-console';

    if (is_aarch64 && get_var('BACKEND') eq 'qemu') {
        record_info 'Skip', 'No nested virt available on aarch64 yet';
        return;
    }

    if (is_x86_64) {
        enter_cmd "qemu-system-x86_64 -nographic -enable-kvm";
        assert_screen 'qemu-no-bootable-device', 60;
    }
    elsif (is_ppc64le) {
        enter_cmd "qemu-system-ppc64 -nographic -enable-kvm";
        assert_screen ['qemu-open-firmware-ready', 'qemu-does-not-support-1tib-segments', 'qemu-ppc64-no-trans-mem'], 60;
        if (match_has_tag 'qemu-does-not-support-1tib-segments') {
            record_soft_failure 'bsc#1124589 - qemu on ppx64le fails when called with kvm on POWER9';
            return;
        }
        elsif (match_has_tag 'qemu-ppc64-no-trans-mem') {
            # this should only happen on SLE12SP5
            record_info 'workaround', 'bsc#1118450 - qemu-system-ppc64: KVM implementation does not support Transactional Memory';
            enter_cmd "qemu-system-ppc64 -nographic -enable-kvm -M usb=off,cap-htm=off";
            assert_screen 'qemu-open-firmware-ready', 60;
        }
    }
    elsif (is_s390x) {
        # Native kvm requires SIE support (start-interpretive execution)
        die "SIE support on s390x cpu required for native kvm" if (script_run('grep sie /proc/cpuinfo') != 0);

        # ===================================================================
        # EVIDENCE COLLECTION (bsc#1265883)
        # All record_info output is visible in the openQA job Details page
        # and can be directly pasted into the bug report.
        # ===================================================================

        # 1. Kernel information (required by bug template)
        record_info 'uname', script_output('uname -a');
        record_info 'kernel-default', script_output('rpm -qi kernel-default');

        # 2. qemu binary in use (requested by Olaf Hering)
        record_info 'qemu binary', script_output('rpm -qf /usr/bin/qemu-system-s390x; qemu-system-s390x --version');

        # 3. boot asset sizes + md5 so devs can retrieve the exact files
        record_info 'boot assets', script_output('ls -lh /boot/image /boot/initrd && md5sum /boot/image /boot/initrd');

        # 4. virtio drivers in initrd (requested by Olaf Hering:
        #    "good-logs swallow all kernel output in initrd, so it is
        #     unclear when virtio becomes active")
        record_info 'initrd virtio', script_output(
            'lsinitrd /boot/initrd 2>&1 | grep -i virtio || echo "(no virtio modules found in initrd)"'
        );

        # 5. Full list of initqueue/finished hooks — key regression evidence.
        #    In PI-231.1 (good) these hooks did NOT exist.
        #    In PI-234.1+ (bad) devexists-ccw-*.sh and wait-zipl-conf.sh appear,
        #    causing ~148-222s stall when no CCW disk is provided to qemu.
        my $all_hooks = script_output(
            'lsinitrd /boot/initrd 2>&1 | grep "initqueue/finished" || echo "(no initqueue/finished hooks)"'
        );
        record_info 'initqueue hooks', $all_hooks;

        # 6. Detect the specific regression hooks introduced in PI-234.1
        my $regression_hooks = script_output(
            'lsinitrd /boot/initrd 2>&1 | grep -E "devexists-ccw|wait-zipl-conf" || true'
        );
        if ($regression_hooks) {
            record_info 'REGRESSION DETECTED', "bsc#1265883: The following hooks were NOT present in PI-231.1\n"
                . "and cause ~148-222s dracut timeout when qemu is started without a disk:\n\n"
                . $regression_hooks, result => 'fail';
        } else {
            record_info 'initrd clean', 'No bsc#1265883 regression hooks (devexists-ccw / wait-zipl-conf) detected';
        }

        # ===================================================================
        # REPRODUCTION: bare command (no disk, no root=)
        # On PI-231.1 (good): reaches Basic System in <30s
        # On PI-234.1+ (bad): dracut stalls, screen stays blank for >148s
        # ===================================================================
        my $t_bare_start = time();
        my $bare_cmdline = 'qemu-system-s390x -nographic -enable-kvm -m 1G'
            . ' -kernel /boot/image -initrd /boot/initrd'
            . ' -append "debug printk.devkmsg=on initcall_debug"';
        record_info 'bare cmdline', $bare_cmdline;
        enter_cmd $bare_cmdline;
        my $bare_match = check_screen('qemu-reached-target-basic-system', 30);
        my $t_bare_elapsed = time() - $t_bare_start;

        if ($bare_match) {
            record_info 'bare boot OK', "Reached Basic System in ${t_bare_elapsed}s with bare command - no regression";
        } else {
            record_soft_failure "bsc#1265883 - bare qemu boot did NOT reach Basic System within 30s "
                . "(elapsed: ${t_bare_elapsed}s) - initrd CCW/zipl hooks stalling dracut";
            send_key 'ctrl-a';
            send_key 'x';
            assert_screen 'root-console', 30;

            # ===============================================================
            # WORKAROUND: root=/dev/ram0 rw
            # Suggested by Antoine Ginies (bsc#1265883 comment#3).
            # Makes dracut use the ramdisk as root, bypassing CCW/zipl hooks.
            # ===============================================================
            my $t_wa_start = time();
            my $wa_cmdline = 'qemu-system-s390x -nographic -enable-kvm -m 1G'
                . ' -kernel /boot/image -initrd /boot/initrd'
                . ' -append "root=/dev/ram0 rw debug printk.devkmsg=on initcall_debug"';
            record_info 'workaround cmdline', $wa_cmdline;
            enter_cmd $wa_cmdline;
            assert_screen 'qemu-reached-target-basic-system', 120;
            my $t_wa_elapsed = time() - $t_wa_start;
            record_info 'workaround OK', "Reached Basic System in ${t_wa_elapsed}s with root=/dev/ram0 rw - "
                . "workaround confirmed effective (bsc#1265883 comment#3)";
            # close workaround qemu before returning to host shell
            send_key 'ctrl-a';
            send_key 'x';
            assert_screen 'root-console', 30;
        }
    }
    elsif (is_aarch64) {
        enter_cmd "qemu-system-aarch64 -M virt,usb=off,gic-version=host -cpu host -enable-kvm -nographic -pflash flash0.img -pflash flash1.img";
        assert_screen([qw(qemu-enter-boot-manager qemu-uefi-shell)], 600);
        if (match_has_tag('qemu-enter-boot-manager')) {
            send_key('e');
            assert_screen('qemu-uefi-boot-manager');
        }
    }

    # close qemu
    send_key 'ctrl-a';
    send_key 'x';
    assert_script_run '$(exit $?)';
}

1;
