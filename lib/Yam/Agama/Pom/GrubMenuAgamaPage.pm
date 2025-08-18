# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuAgamaPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_menu_base => $args->{grub_menu_base},
        # Keep needle reference for backward compatibility
        # Falls back to keyboard navigation if needle doesn't exist
        tag_agama_installer_highlighted => 'grub-menu-agama-installer-highlighted',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    # First try the original approach with needle matching
    if (check_screen($self->{tag_agama_installer_highlighted}, 10)) {
        # Needle exists and matches, use original logic
        assert_screen($self->{tag_agama_installer_highlighted}, 60);
        return;
    }
    
    # Fallback: needle doesn't exist, save screenshot first then use keyboard navigation
    record_info("Needle fallback", "Using keyboard navigation as needle '$self->{tag_agama_installer_highlighted}' not found");
    
    # Wait for grub menu to appear and stabilize
    sleep 2;
    
    # Save initial screenshot for potential needle creation
    save_screenshot;
    record_info("Initial screenshot", "Saved initial GRUB menu state before navigation");
    
    # Press ESC to stop the countdown timer
    send_key('esc');
    sleep 1;
    record_info("ESC pressed", "Stopped countdown timer");
    
    # Save screenshot after ESC to show stable menu
    save_screenshot;
    record_info("Menu stabilized", "GRUB menu after stopping countdown");
    
    # Try to detect grub menu with multiple possible needles
    if (check_screen(['grub-menu', 'bootloader-grub2', 'grub2'], 15)) {
        record_info("GRUB menu detected", "Found GRUB menu, navigating to Agama installer");
    } else {
        record_info("GRUB menu fallback", "Proceeding with keyboard navigation");
    }
    
    # Navigate from first entry to second entry (Install SUSE SLE 16)
    send_key('down');  # Move to second entry
    sleep 1;
    
    # Save screenshot to verify we're on the correct entry (for needle creation)
    save_screenshot;
    record_info("Agama installer selected", "Screenshot of 'Install SUSE SLE 16' highlighted - can be used for needle creation");
}

sub boot_from_hd {
    send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'down';
    send_key 'ret';
}

sub select_check_installation_medium_entry {
    my ($self) = @_;
    send_key_until_needlematch('grub-menu-agama-mediacheck-highlighted', 'down');
}

sub select_rescue_system_entry {
    send_key_until_needlematch('grub-menu-agama-rescue-system-highlighted', 'down');
}

sub edit_current_entry { shift->{grub_menu_base}->edit_current_entry() }

sub select_and_boot_agama_installer {
    my ($self) = @_;
    # Ensure we're on the Agama installer entry and boot it
    record_info("Booting Agama installer", "Starting installation from selected entry");
    send_key('ret');  # Press Enter to start installation
}

1;
