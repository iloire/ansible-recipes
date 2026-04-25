# Testing the playbook in a VM

You don't want to find out the playbook breaks on a fresh box *during* install day. The repo ships a [`Vagrantfile`](../Vagrantfile) that boots a clean Ubuntu 24.04 VM and runs the playbook against it — same constraints as 26.04 (libfuse2t64, modern apt keyrings, no apt-key).

## One-time setup

Already done on pepinaco (vagrant + virtualbox are in `apt_packages`). On a fresh control machine:

```bash
sudo apt install -y vagrant virtualbox-7.1
```

**Use VirtualBox 7.1+, not 6.1.** Ubuntu 22.04's distro-shipped `virtualbox` is 6.1 and crashes (`VERR_VMM_SET_JMP_ABORTED_RESUME` / GuruMeditation) under any recent kernel (6.5+). Add Oracle's repo:

```bash
wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | \
  gpg --dearmor | sudo tee /etc/apt/keyrings/virtualbox.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/virtualbox.gpg] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | \
  sudo tee /etc/apt/sources.list.d/virtualbox.list
sudo apt update && sudo apt install -y virtualbox-7.1
```

VirtualBox 7.x also coexists with KVM via the KVM API — no need to `modprobe -r kvm_intel`.

## The basic loop (recommended path: scripts/test-vm.sh)

[`scripts/test-vm.sh`](../scripts/test-vm.sh) wraps everything with `set -euo pipefail`, healthchecks with retry, structured logging, and clear failure summaries. Use it instead of raw `vagrant up` / `vagrant provision` — it survives intermittent SSH issues that bare vagrant doesn't.

```bash
cd ~/code/ansible-recipes

# First boot: downloads the box (~600 MB), boots, installs ubuntu-desktop,
# runs the full default-tag playbook. ~30 min start to finish.
# Open the VirtualBox window during boot:
VB_GUI=true ./scripts/test-vm.sh up

# Snapshot the clean state for fast rollback:
vagrant snapshot save clean

# Iterate on a single role:
ANSIBLE_TAGS=ubuntu_settings ./scripts/test-vm.sh provision

# Run the FULL play (slow, ~30+ min, surfaces long-tail role failures):
ANSIBLE_TAGS=all ./scripts/test-vm.sh provision

# Probe state without changing anything (also tails the latest log):
./scripts/test-vm.sh status

# When something breaks badly:
vagrant snapshot restore clean
./scripts/test-vm.sh provision
```

Every run writes a timestamped log to `logs/test-vm-<UTC>.log` plus a `logs/latest.log` symlink. The script tees stdout+stderr through `tee` so the log is complete even if a phase crashes mid-run (the failure mode that bit us on 2026-04-25 — bash chains losing their stdout to a dead SSH session).

## What the script does (under the hood)

```
Phase 0  vagrant up --no-provision     boot the VM, download the box if needed
Phase 1  apt install ubuntu-desktop    so you can log in via the VBox GUI
Phase 2  systemctl isolate graphical   GDM appears in the window
Phase 3  vagrant provision             actual playbook run (the test)
```

Healthcheck (`vagrant ssh -c true`) runs between phases with 8 retries × 8s — catches sshd briefly refusing connections during heavy package installs.

## Raw `vagrant` commands (when you don't need the wrapper)

```bash
vagrant up                                        # boot only
vagrant snapshot save clean                       # capture state
vagrant snapshot restore clean                    # roll back
ANSIBLE_TAGS=apt vagrant provision                # one tag
ANSIBLE_VERBOSE=vv vagrant provision              # debug an ansible failure
vagrant ssh                                       # interactive shell as vagrant user
vagrant destroy -f                                # nuke
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
| `VERR_VMM_SET_JMP_ABORTED_RESUME` / "GuruMeditation" on `vagrant up` | VirtualBox 6.1 + kernel 6.x. Upgrade to VBox 7.x (see one-time setup above). |
| `kex_exchange_identification: Connection reset by peer` from `vagrant ssh` | sshd in the VM hit MaxStartups (too many concurrent SSH connections). `vagrant reload --no-provision` to recover. The `test-vm.sh` healthcheck handles transient cases. |
| "timeout during server version negotiating" from `vagrant provision` | Same root cause as above — concurrent SSH from a stuck wrapper script. Kill any stale `bash -c '...vagrant ssh...'` processes, then `vagrant reload`. |
| `git clone git@github.com:iloire/dotfiles.git` fails | `ssh-add ~/.ssh/id_ed25519` on the host before `vagrant up`. The Vagrantfile sets `forward_agent = true`. |
| "ansible_local installer failed" | The box's apt cache is stale — `vagrant ssh -c "sudo apt update"`, then `vagrant provision` |
| VirtualBox kernel module not loaded | `sudo /sbin/vboxconfig` (when DKMS hasn't rebuilt after a kernel upgrade) |
| `vboxnet0` host-only network missing | `vboxmanage hostonlyif create` |
| Playbook hangs on a `become` task | sudo password prompt waiting in the dark — Vagrant's vagrant user has passwordless sudo, but if a task runs as a different user it'll hang. Check with `ANSIBLE_VERBOSE=vv` |
| 5-minute timeout on `vagrant up` | The box download is slow on first run. Pre-download with `vagrant box add bento/ubuntu-24.04` |
| Bash wrapper scripts dying silently when running multi-phase work | This is why `scripts/test-vm.sh` exists. Don't chain `vagrant ssh` commands in a one-shot bash script — when sshd briefly drops (during heavy installs), the script's pipe breaks and SIGPIPE kills it. The script uses healthchecks + retries + a single `exec > >(tee)` redirection that survives sub-process death. |

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
