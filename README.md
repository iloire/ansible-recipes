![I, Robot](https://raw.githubusercontent.com/iloire/ansible-recipes/master/robot.png)

# ansible-recipes

Ansible playbooks for automating development environment setup across Ubuntu Linux and macOS. One command to go from a fresh install to a fully configured workstation.

## What gets installed

### Cross-platform (shared)

- **Shell**: zsh + oh-my-zsh, tmux + tmuxinator, dotfiles symlinks
- **Dev tools**: Node.js (via nvm), npm global packages (prettier, pyright, typescript-language-server, yarn, nodemon, diff-so-fancy)
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

## Configurations

There are four setup profiles:

| Profile | Target | Script |
|---------|--------|--------|
| **Ubuntu Desktop** | Full dev workstation | `./run-desktop-ubuntu.sh` |
| **Ubuntu Server** | Minimal CLI environment | `ansible-playbook server-ubuntu.yml -K` |
| **macOS Desktop** | Full dev workstation | `./run-desktop-osx.sh` |
| **macOS Agent** | Minimal LLM agent machine | `./run-desktop-osx-agent.sh` |

## Getting started

### Ubuntu

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
./run-desktop-ubuntu.sh
```

Or use the install script: `./install-ansible-linux.sh`

### macOS

```bash
# 1. Generate SSH key
ssh-keygen -t ed25519

# 2. Install Homebrew, git, and ansible
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git ansible

# 3. Clone and run
git clone git@github.com:iloire/ansible-recipes.git
cd ansible-recipes
./run-desktop-osx.sh
```

## Running individual playbooks

You don't have to run the full setup. Run a single playbook with the helper scripts:

```bash
# List available playbooks
./run-playbook-ubuntu.sh
./run-playbook-osx.sh

# Run a specific one
./run-playbook-ubuntu.sh docker
./run-playbook-osx.sh homebrew
```

## Project structure

```
├── desktop-ubuntu.yml           # Main Ubuntu desktop orchestrator
├── desktop-osx.yml              # Main macOS desktop orchestrator
├── desktop-osx-agent.yml        # Minimal macOS agent setup
├── server-ubuntu.yml            # Ubuntu server orchestrator
├── playbooks/
│   ├── linux/                   # Ubuntu-specific playbooks
│   ├── osx/                     # macOS-specific playbooks
│   ├── dotfiles.yml             # Shared: dotfiles + oh-my-zsh
│   ├── node.yml                 # Shared: nvm + Node.js
│   ├── npm-packages.yml         # Shared: global npm packages
│   ├── tmux-config.yml          # Shared: tmux + tmuxinator
│   ├── git-config.yml           # Shared: gitconfig symlink
│   ├── hosts.yml                # Shared: ad-blocking hosts file
│   ├── crontab.yml              # Shared: maintenance cron jobs
│   ├── claude.yml               # Shared: Claude CLI config
│   └── ...
├── run-*.sh                     # Convenience runner scripts
└── install-ansible-*.sh         # Ansible installation helpers
```

## Dependencies

The playbooks expect these external repositories (cloned automatically):

- [iloire/dotfiles](https://github.com/iloire/dotfiles) — shell configs, editor settings, tmux config
- [iloire/myconfig](https://github.com/iloire/myconfig) — personal configuration
- [iloire/qmk_firmware](https://github.com/iloire/qmk_firmware) — custom keyboard firmware
