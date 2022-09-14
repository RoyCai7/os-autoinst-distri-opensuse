# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Customer Center dialog in YaST Firstboot Configuration
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;

sub run {
    $testapi::distri->get_registration_of_registered_system()
      ->proceed_with_current_configuration();
}

1;