local repo = '{{INCIDENT_REPO}}';
local urls = if repo != '' then std.split(repo, ',') else [];
local arch = '{{ARCH}}';
local firmware_package = if arch == 'aarch64' then 'qemu-uefi-aarch64' else if arch == 'ppc64le' then 'qemu-slof' else 'ovmf';
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
    mode: 'immutable',
  },
  bootloader: {
    stopOnBootMenu: true,
  },
  root: {
    password: '$6$0bUrc6YvA/qw$h1Z3pzadaxmc/KgcHRSEcYoU1ShVNymoXBaRAQZJ4ozVhTbCvdAMbGQrQAAX7cC9cLRybhsvDio3kBX/IB3xj/',
    hashedPassword: true,
    sshPublicKey: '{{_SECRET_ED25519_PUB_KEY}}',
  },
  software: {
    patterns: ['base', 'kvm_server', 'kvm_tools'],
    packages: ['openssh-server-config-rootlogin', 'curl', 'libvirt-client', 'virt-install', 'libguestfs0', 'guestfs-tools', firmware_package, 'iputils', 'nmap', 'supportutils'],
    extraRepositories:
      if std.length(urls) > 0 then
        [
          {
            alias: 'TEST_' + std.toString(i),
            url: urls[i],
            allowUnsigned: true,
          }
          for i in std.range(0, std.length(urls) - 1)
        ]
      else
        [],
    onlyRequired: false,
  },
  questions: {
    policy: 'auto',
    answers: [{answer: 'Trust', class: 'software.import_gpg'}],
  },
  scripts: {
    post: [
      {
        name: 'configure_host_ssh',
        chroot: true,
        content: |||
          #!/bin/bash
          set -eu
          install -d -m 700 /root/.ssh
          cat > /root/.ssh/id_ed25519 << 'EOF'
          {{_SECRET_ED25519_PRIV_KEY}}
          EOF
          sed -i 's/9A/\n/g' /root/.ssh/id_ed25519
          chmod 600 /root/.ssh/id_ed25519
          echo '{{_SECRET_ED25519_PUB_KEY}}' > /root/.ssh/id_ed25519.pub
          cat > /root/.ssh/config << 'EOF'
          Host *
              StrictHostKeyChecking accept-new
              BatchMode yes
              ConnectTimeout 15
          EOF
          chmod 600 /root/.ssh/config
        |||,
      },
    ],
  },
}