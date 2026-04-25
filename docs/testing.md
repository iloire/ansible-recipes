# Testing the playbook in a VM

You don't want to find out the playbook breaks on a fresh box *during* install day. The repo ships a [`Vagrantfile`](../Vagrantfile) that boots a clean Ubuntu 24.04 VM and runs the playbook against it — same constraints as 26.04 (libfuse2t64, modern apt keyrings, no apt-key).

## One-time setup

Already done on pepinaco (vagrant + virtualbox are in `apt_packages`). On a fresh control machine:

```bash
sudo apt install -y vagrant virtualbox
```

VirtualBox 6.1 (Ubuntu 22.04 default) and 7.x both work with the `bento/ubuntu-24.04` box.

## The basic loop

```bash
cd ~/code/ansible-recipes

# First boot: downloads the box (~600 MB), boots, runs ansible.
# 10–15 min depending on apt mirror speed.
vagrant up

# Save a clean post-OS-install snapshot. From this point any provision
# run can be reset to pristine in seconds.
vagrant snapshot save clean

# Iterate on a single role. Edit the role, then:
ANSIBLE_TAGS=ubuntu_settings vagrant provision

# When something breaks badly:
vagrant snapshot restore clean
vagrant provision
```

## Tag selection

Default tags (when you just run `vagrant up` or `vagrant provision`):

```
apt_minimum, apt, docker, brave, google_chrome, onepassword,
github_desktop, modern_cli_tools, ubuntu_settings
```

This is the install-day critical path. Skips heavy stuff (`anaconda`, `whisper_cpp`, `qmk`, GUI bits like `vscode_config`/`alacritty_config` that need the actual desktop) so you iterate fast.

Override per-run:

```bash
ANSIBLE_TAGS=apt vagrant provision                       # only apt + third-party repos
ANSIBLE_TAGS=docker,modern_cli_tools vagrant provision   # multiple roles
ANSIBLE_TAGS=all vagrant provision                       # the full play (slow, ~30+ min)
```

## What this catches

The VM run will fail on exactly the things that would fail on install day:

- A package missing from a third-party repo (typo in `apt_third_party_repos.repo`)
- A 24.04+ name change (e.g. `libfuse2` → `libfuse2t64`) the playbook didn't anticipate
- A GPG key URL that 404s
- A role assuming a tool exists that isn't installed yet (ordering bugs)
- `apt-key` calls that silently work on 22.04 but fail on 24.04+

## What this does NOT catch

- **GUI behavior** — the VM runs headless (`vb.gui = false`) and 3D accel is off, so anything that needs a logged-in GNOME session won't fully exercise. Useful: dconf settings still apply (they go into the dconf database whether the user session is live or not).
- **NVIDIA driver** — the VM has no real GPU. The `nvidia-driver-525` package install may succeed or fail depending on the kernel, but `nvidia-smi` won't ever work. Plan for this on the real hardware.
- **Hardware-specific things** — the DATA drive UUID, the HDMI audio sink in `pactl.desktop`, the `DP-0` monitor name in the dash-to-dock dconf. These are flagged in the [install runbook](26.04-install-runbook.md) as manual steps.
- **Things gated by SSH agent forwarding** — work fine if you `ssh-add` your GitHub key on the host before `vagrant up` (the Vagrantfile sets `forward_agent = true`). Otherwise the dotfiles role's git clone will fail.

## Common gotchas

| Symptom | Fix |
|---|---|
| `git clone git@github.com:iloire/dotfiles.git` fails | `ssh-add ~/.ssh/id_ed25519` on the host before `vagrant up` |
| "ansible_local installer failed" | The box's apt cache is stale — `vagrant ssh -c "sudo apt update"`, then `vagrant provision` |
| VirtualBox kernel module not loaded | `sudo /sbin/vboxconfig` (when DKMS hasn't rebuilt after a kernel upgrade) |
| `vboxnet0` host-only network missing | `vboxmanage hostonlyif create` |
| Playbook hangs on a `become` task | sudo password prompt waiting in the dark — Vagrant's vagrant user has passwordless sudo, but if a task runs as a different user it'll hang. Check with `--verbose` |
| 5-minute timeout on `vagrant up` | The box download is slow on first run. Pre-download with `vagrant box add bento/ubuntu-24.04` |

## Snapshot strategy

```bash
vagrant snapshot list                      # what snapshots exist
vagrant snapshot save <name>               # capture current state
vagrant snapshot restore <name>            # roll back (instant)
vagrant snapshot delete <name>             # free disk
```

Useful pattern: snapshot after each successful tag run, so you can diff "before role X" vs "after role X" by booting both:

```bash
ANSIBLE_TAGS=apt vagrant provision
vagrant snapshot save post-apt
ANSIBLE_TAGS=docker vagrant provision
vagrant snapshot save post-docker
# ...
```

## When the test passes, update the runbook

If a fresh `vagrant up && vagrant provision` runs clean (or fails only on the documented "what this does NOT catch" set), the playbook is install-day-ready. Update [`docs/26.04-install-runbook.md`](26.04-install-runbook.md):

- Move any item out of "Manual checklist" if you just ansibled it
- Add new gotchas you discovered (so they're in the runbook on install day)
- Bump the "validated against" line at the top

## Cleanup

```bash
vagrant destroy             # remove the VM (keeps snapshots until next up)
vagrant box remove bento/ubuntu-24.04   # also free the ~600 MB box image
```

The `.vagrant/` directory in the repo is gitignored — safe to leave, or `rm -rf .vagrant/` for a totally clean state.
