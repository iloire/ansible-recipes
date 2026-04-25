# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Test the desktop-ubuntu playbook against a fresh Ubuntu 24.04 box.
# 24.04 has the same constraints as 26.04 (libfuse2t64, modern apt
# keyrings, no apt-key, t64 transition packages) so it's a faithful
# preview of the 26.04 install day.
#
# Quick start:
#   vagrant up                                 # boot + run default tags
#   vagrant snapshot save clean                # right after first up, capture pristine state
#   vagrant ssh                                # poke around inside
#   vagrant snapshot restore clean             # back to pristine
#   vagrant provision                          # re-run ansible
#   vagrant destroy                            # nuke it
#
# Iterate on a single role:
#   ANSIBLE_TAGS=apt vagrant provision
#   ANSIBLE_TAGS=ubuntu_settings vagrant provision
#
# Run the full play (slow, lots of apt install):
#   ANSIBLE_TAGS=all vagrant provision
#
# See docs/testing.md for the full workflow.

Vagrant.configure("2") do |config|
  # Box defaults to 26.04 — the actual install target. Override with
  # VAGRANT_BOX=bento/ubuntu-24.04 to test against 24.04 instead
  # (faster — bento boxes are smaller + ship guest additions baked in,
  # while cloud-image boxes are minimal Canonical-published OS images).
  config.vm.box = ENV.fetch("VAGRANT_BOX", "cloud-image/ubuntu-26.04")
  config.vm.hostname = "pepinaco-test"

  # Allow git clone of the dotfiles repo from inside the VM using your
  # host's SSH key — saves embedding a key in the box.
  config.ssh.forward_agent = true

  # Repo is mounted at /vagrant inside the VM (Vagrant default). The
  # ansible_local provisioner reads desktop-ubuntu.yml from there.
  # Synced-folder type defaults to vboxsf, which works fine for read-only
  # ansible runs (no fsnotify needed).

  config.vm.provider "virtualbox" do |vb|
    vb.name = "pepinaco-test"
    vb.gui = ENV.fetch("VB_GUI", "true") == "true"  # VBox window on by default; VB_GUI=false for headless
    vb.memory = 6144           # apt install of ubuntu-desktop + extras eats memory
    vb.cpus = 4
    vb.linked_clone = true     # faster destroy/up cycles

    # 3D accel is off — VirtualBox 6.1 + Ubuntu 24.04 GNOME has issues; we
    # don't need a working desktop session, just want the playbook to run.
    vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
    vb.customize ["modifyvm", :id, "--vram", "64"]
  end

  # ansible_local installs ansible inside the VM and runs from there.
  # No SSH/inventory dance — just runs against localhost in the linux group.
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "desktop-ubuntu.yml"
    ansible.compatibility_mode = "2.0"
    ansible.install_mode = "default"   # apt install ansible (latest from PPA in the box)
    # ANSIBLE_VERBOSE=v / vv / vvv sets the matching ansible -v level so failed
    # playbooks have actionable detail. Default is "v" — adds task-level
    # before/after, which is the right tradeoff between noise and forensics.
    ansible.verbose = ENV.fetch("ANSIBLE_VERBOSE", "v")

    # The playbook says `hosts: linux` — put the vagrant box in that group.
    ansible.groups = {
      "linux" => ["default"]
    }

    # Default to a meaningful subset that exercises the install-day
    # critical path without burning 60 minutes per run. Override via
    # ANSIBLE_TAGS env var (e.g. ANSIBLE_TAGS=all for the full play).
    ansible.tags = ENV.fetch(
      "ANSIBLE_TAGS",
      "apt_minimum,apt,docker,brave,google_chrome,onepassword,github_desktop,modern_cli_tools,ubuntu_settings"
    ).split(",")

    # The dotfiles role tries to symlink ~/.ssh/config — skip that for
    # the vagrant user (it has its own ssh setup managed by vagrant).
    ansible.extra_vars = {
      dotfiles_link_ssh_config: false
    }
  end
end
