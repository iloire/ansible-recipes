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

## Machines

Three machines are defined in `inventory/hosts.yml`:

| Machine | Profile | Connection |
|---------|---------|------------|
| `dev-machine` | Ubuntu Desktop | local |
| `macbook` | macOS Desktop | SSH (remote) |
| `osx-agent` | macOS Agent | SSH (remote) |

Edit `inventory/hosts.yml` to set the IP addresses for your remote machines.

## Usage

```bash
# Provision your linux dev machine
./run.sh --limit dev-machine

# Provision your macOS laptop (remote)
./run.sh --limit macbook

# Provision the macOS agent (remote)
./run.sh --limit osx-agent

# Provision all machines
./run.sh

# Run a single role on a specific machine
./run.sh --tags docker --limit dev-machine
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
./run.sh --limit dev-machine
```

Or use the install script: `./install-ansible-linux.sh`

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
│   ├── all.yml                  # Shared variables (nvm version, repos, npm packages)
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
├── server-ubuntu.yml            # Profile: Ubuntu server (CLI only)
├── site.yml                     # Master playbook (imports all profiles)
├── run.sh                       # Single runner script
└── install-ansible-*.sh         # Ansible installation helpers
```

## Dependencies

The roles expect these external repositories (cloned automatically):

- [iloire/dotfiles](https://github.com/iloire/dotfiles) — shell configs, editor settings, tmux config
- [iloire/myconfig](https://github.com/iloire/myconfig) — personal configuration
- [iloire/qmk_firmware](https://github.com/iloire/qmk_firmware) — custom keyboard firmware
