# docs

In-repo documentation for things the top-level [README](../README.md) is too high-level to cover.

| Doc | What it's for |
|---|---|
| [patterns.md](patterns.md) | How to add new packages without role explosion. Read before creating a new role. Covers `apt_third_party_repos`, the `dotfiles` role contract, and the `ubuntu_settings` dconf catalog. |
| [testing.md](testing.md) | Run the playbook against a fresh Ubuntu 24.04 VM via Vagrant + VirtualBox. Catches install-day breakage before install day. |
| [26.04-install-runbook.md](26.04-install-runbook.md) | Day-of-install checklist for moving pepinaco to Ubuntu 26.04. The strategic goal of every recent commit is to make this list short. |

For external context (why this repo exists, what gets installed on each profile, how to bootstrap), see the top-level [README](../README.md).

For finding what's drifted between a live machine and the playbook, see [`scripts/audit-drift.sh`](../scripts/audit-drift.sh) and the "Finding configuration drift" section of the README.
