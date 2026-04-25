![I, Robot](https://raw.githubusercontent.com/iloire/ansible-recipes/master/robot.png)

# ansible-recipes

Ansible roles for automating development environment setup across Ubuntu Linux and macOS. Provision local or remote machines with a single command.

## What gets installed

### Cross-platform (shared)

- **Shell**: zsh + oh-my-zsh, tmux + tmuxinator, dotfiles symlinks
- **Modern CLI**: eza (ls), bat (cat), fd (find), dust (du), btop (top), tldr (man), delta (diff), atuin (shell history)
- **Dev tools**: Node.js (via nvm), npm global packages (prettier, pyright, typescript-language-server, yarn, nodemon)
- **Editors**: Neovim, VS Code, Cursor (all configured via dotfiles symlinks)
- **Git**: git-crypt, git-lfs, lazygit, custom `.gitconfig`
- **System**: ad-blocking hosts file (StevenBlack/hosts), cron jobs for cleanup and maintenance
- **AI**: Claude CLI configuration

### Ubuntu desktop

- **Packages (apt)**: docker, build-essential, htop, ripgrep, fzf, nmap, flameshot, vlc, obs-studio, libreoffice, gh, jq, and more
- **Packages (snap)**: spotify, discord, obsidian, gimp, blender, zoom, todoist
- **Packages (flatpak)**: deskflow
- **Browsers**: Google Chrome, Brave
- **Fonts**: Hack, JetBrains Mono, Droid Sans Mono, Ubuntu Mono (Nerd Font variants)
- **Desktop**: GNOME settings (dark theme, dock apps, keyboard repeat rate, caps lock → escape, night light, screenshot shortcuts)
- **Other**: 1Password, Vagrant, Anaconda/Miniconda, Alacritty, Terminator, GitHub Desktop

### macOS desktop

- **Homebrew casks**: Docker, Google Chrome, Brave, Firefox, Spotify, Postman, Tower, Arduino IDE, KeePassX, and more
- **Homebrew packages**: git, go, python, terraform, awscli, neovim, lazygit, ripgrep, fzf, tmux, and more
- **System**: Finder preferences (show hidden files, extensions, Library), fast key repeat, tap-to-click, screenshots to `~/Screenshots`, caps lock → escape
- **Dock**: removes default apps, adds Chrome/Spotify/Google Drive, smaller tile size
- **Fonts**: all available Nerd Fonts via Homebrew

### macOS agent (minimal)

Lightweight setup for a machine running LLM agents — no heavy dev tools:

- **Homebrew casks**: Google Chrome, KeePassX, Tailscale
- **Homebrew packages**: git, git-crypt, git-lfs, jq, wget, tree, ripgrep, fzf, tmux, tmuxinator, fastfetch, zsh + plugins
- **Config**: dotfiles, tmux, node, npm, git, hosts file, Claude CLI

### Home Assistant (Raspberry Pi)

Manages a Raspberry Pi running Home Assistant OS (Alpine-based):

- **Bootstrap**: Python 3 (via apk)
- **Config**: dotfiles, git config

## Machines

Five machines are defined in `inventory/hosts.yml`:

| Machine       | Profile        | Connection   |
| ------------- | -------------- | ------------ |
| `pepinaco`    | Ubuntu Desktop | local        |
| `macbook`     | macOS Desktop  | SSH (remote) |
| `osx-agent`   | macOS Agent    | SSH (remote) |
| `hassio`      | Home Assistant | SSH (remote) |
| `peque`       | NAS (Linux)    | SSH (remote) |

> **peque** is the home NAS (ansible-nas based). This repo manages only the **user-scope** concerns on peque: dotfiles, user cron jobs (watchdog, low-space monitor, docker cleanup), shell config. Container stacks, storage, networking, and other system-level concerns are managed by the separate [`NAS-peque/ansible-nas`](../NAS-peque) repo. See [CLAUDE.md](CLAUDE.md) for the scope boundary.

Edit `inventory/hosts.yml` to set the IP addresses for your remote machines.

## Usage

```bash
# Provision your linux dev machine
./run.sh --limit pepinaco

# Provision your macOS laptop (remote)
./run.sh --limit macbook

# Provision the macOS agent (remote)
./run.sh --limit osx-agent

# Provision Home Assistant (remote)
./run.sh --limit hassio

# Provision all machines
./run.sh

# Run a single role on a specific machine
./run.sh --tags docker --limit pepinaco
./run.sh --tags homebrew --limit macbook
```

## Getting started

### Ubuntu (local machine)

```bash
# 1. Generate SSH key
ssh-keygen -t ed25519

# 2. Install git and ansible
sudo apt update
sudo apt install -y git software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# 3. Clone and run
git clone git@github.com:iloire/ansible-recipes.git
cd ansible-recipes
./run.sh --limit pepinaco
```

Or use the install script: `./scripts/install-ansible-linux.sh`

### macOS (local or remote)

```bash
# 1. Generate SSH key
ssh-keygen -t ed25519

# 2. Install Homebrew, git, and ansible
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git ansible

# 3. Clone and run locally, or configure for remote provisioning
git clone git@github.com:iloire/ansible-recipes.git
cd ansible-recipes
./run.sh --limit macbook
```

### Remote provisioning

To provision macOS machines remotely from your Linux dev machine:

1. Edit `inventory/hosts.yml` and set the IPs for `macbook` and `osx-agent`
2. Ensure SSH key auth is set up: `ssh-copy-id ivan@<MACBOOK_IP>`
3. Enable Remote Login on macOS: System Settings → General → Sharing → Remote Login
4. Run: `./run.sh --limit macbook`

## Project structure

```
├── ansible.cfg                  # Ansible config (inventory path, roles path)
├── inventory/
│   └── hosts.yml                # All machines defined here
├── group_vars/
│   ├── all/
│   │   ├── vars.yml             # Shared variables (nvm version, repos, npm packages)
│   │   └── secrets.yml          # Encrypted secrets (git-crypt)
│   ├── linux.yml                # Linux package lists and settings
│   └── osx.yml                  # macOS homebrew packages, dock config
├── host_vars/
│   └── osx-agent.yml            # Agent-specific homebrew overrides (minimal)
├── roles/
│   ├── dotfiles/                # Shared: dotfiles + oh-my-zsh
│   ├── node/                    # Shared: nvm + Node.js
│   ├── npm_packages/            # Shared: global npm packages
│   ├── tmux/                    # Shared: tmux + tmuxinator
│   ├── git_config/              # Shared: gitconfig symlink
│   ├── hosts_file/              # Shared: ad-blocking hosts file
│   ├── crontab/                 # Shared: maintenance cron jobs
│   ├── modern_cli_tools/        # Shared: eza, bat, fd, dust, btop, tldr, delta, atuin
│   ├── claude/                  # Shared: Claude CLI config
│   ├── docker/                  # Linux: Docker CE
│   ├── homebrew/                # macOS: Homebrew packages + casks
│   └── ...                      # 36 roles total
├── desktop-ubuntu.yml           # Profile: Ubuntu desktop (all roles)
├── desktop-osx.yml              # Profile: macOS desktop (all roles)
├── desktop-osx-agent.yml        # Profile: macOS agent (minimal roles)
├── homeassistant.yml            # Profile: Home Assistant (dotfiles + backup sync)
├── server-ubuntu.yml            # Profile: Ubuntu server (CLI only)
├── site.yml                     # Master playbook (imports all profiles)
├── run.sh                       # Single runner script
└── scripts/
    ├── install-ansible-linux.sh # Bootstrap Ansible on Ubuntu/Debian
    ├── install-ansible-mac.sh   # Bootstrap Ansible on macOS
    └── audit-drift.sh           # Find config drift on a live machine vs the playbook
```

## Bootstrap scripts

Before running the playbooks, Ansible must be installed on the control machine. The [scripts/](scripts/) directory contains bootstrap scripts for a fresh install:

| Script                             | Platform      | What it does                                       |
| ---------------------------------- | ------------- | -------------------------------------------------- |
| `scripts/install-ansible-linux.sh` | Ubuntu/Debian | Adds the official Ansible PPA and installs via apt |
| `scripts/install-ansible-mac.sh`   | macOS         | Installs Ansible via Homebrew                      |

```bash
# Ubuntu/Debian
./scripts/install-ansible-linux.sh

# macOS (requires Homebrew)
./scripts/install-ansible-mac.sh
```

## Finding configuration drift

Over time a working machine accumulates apps, tweaks, and settings that never make it back into the playbook — so a fresh install reproduces most-but-not-all of the daily setup. The `audit-drift.sh` script compares **current machine state** against **what's captured in ansible-recipes** and prints a gap report.

**When to run it**

- Before a planned reinstall / OS upgrade — close gaps now, so `./run.sh` is actually "everything".
- Periodically (quarterly?) to catch drift early while you still remember what you installed and why.

**How to run it** (Linux only — uses apt, snap, flatpak, dconf, systemctl):

```bash
# Prints the markdown report to stdout and saves a timestamped copy:
./scripts/audit-drift.sh | tee /tmp/drift-$(hostname)-$(date +%Y-%m-%d).md
```

Read-only, no changes made. Also writes a full `dconf` dump to `/tmp/dconf-dump-<host>-<date>.ini` for deeper review.

**What it checks**

| Category | Source of truth in the repo |
| --- | --- |
| apt packages (manually installed) | `apt_packages` + `apt_minimum_packages` in `group_vars/linux.yml` |
| snap packages | `snap_packages` + `snap_classic_packages` |
| flatpak apps | `flatpak_packages` |
| VS Code extensions | Currently unmanaged — all enabled extensions surface as drift |
| GNOME shell extensions | Currently unmanaged — listed for review |
| systemd user services (enabled) | Compare against the `autostart` role |
| User crontab | Compare against `crontab_desktop` / `crontab_server` |
| User groups (non-default) | Look for explicit `user: groups=` tasks |
| `/etc/fstab` custom mounts | Flag for review |
| `dconf` dump size vs coverage | Counts keys captured via `dconf:` tasks in roles |
| Hardcoded gotchas | Flags version-pinned stuff like `nvidia-driver-525`, `python3.10` |

**What to do with the output**

For each listed item, decide:

1. **Add to ansible** — append to the corresponding var list (most common).
2. **New role** — if a whole category is unmanaged (e.g. VS Code extensions).
3. **Manual step** — keep it in the "Day 1 runbook" for stuff that can't be automated (SSH keys, 1Password login, Tailscale auth, NVIDIA driver install + reboot).

The final section of the report is already a manual-bootstrap checklist — use it as the starting point for your Day-1 runbook.

## Dependencies

The roles expect these external repositories (cloned automatically):

- [iloire/dotfiles](https://github.com/iloire/dotfiles) — shell configs, editor settings, tmux config
- [iloire/myconfig](https://github.com/iloire/myconfig) — personal configuration
- [iloire/qmk_firmware](https://github.com/iloire/qmk_firmware) — custom keyboard firmware
