# Patterns

How to extend `ansible-recipes` without creating per-app role explosion. Read this before adding a new app to the playbook.

## Three places a package can live

| Where | When | Cost to add |
|---|---|---|
| `apt_packages` (or `apt_minimum_packages`) in `group_vars/linux.yml` | Package is in the standard Ubuntu apt repos | 1 line |
| `apt_third_party_repos` in `group_vars/linux.yml` | Package needs an extra apt repo + GPG key, but the install itself is just `apt install <name>` | 4 lines (name + key URL + deb line, then add the package name to `apt_packages`) |
| Dedicated `roles/<thing>/` | Install is something other than apt (curl-installed binary, AppImage download, deb-from-URL, Docker setup beyond apt, language toolchain) | A whole role |

**Default to the cheapest option that works.** Most apps fit in one of the first two slots.

## The `apt_third_party_repos` pattern

Most third-party deb repos work the same way:

1. Drop a GPG key into `/etc/apt/keyrings/<name>.gpg`
2. Write a `deb [signed-by=/etc/apt/keyrings/<name>.gpg ...] https://... <suite> <component>` line into `/etc/apt/sources.list.d/<name>.list`
3. `apt install <package>`

Rather than write that 3-step dance per app, `apt_third_party_repos` is a list of `{name, key_url, repo}` dicts. The `apt` role loops over them, downloads each key, dearmors it into `/etc/apt/keyrings/`, and registers the repo via `apt_repository` with `signed-by=`. Then the regular `apt_packages` install picks up the new package.

### Adding a new third-party repo

```yaml
# in group_vars/linux.yml
apt_third_party_repos:
  - name: my-tool                                # → /etc/apt/keyrings/my-tool.gpg
    key_url: https://example.com/signing-key.asc
    repo: "deb [arch=amd64 signed-by=/etc/apt/keyrings/my-tool.gpg] https://example.com/apt stable main"
```

Then add the actual package(s) to `apt_packages`:

```yaml
apt_packages:
  - my-tool
```

The deb line can use Jinja for the suite — `{{ ansible_distribution_release }}` resolves to `jammy` on 22.04, `noble` on 24.04, etc. — so the same line works across Ubuntu versions.

### When NOT to use `apt_third_party_repos`

- **The repo install is non-trivial** (e.g. needs to ARCH-substitute the URL, registers multiple .list files, sets debconf options). Write a dedicated role.
- **There's already a dedicated role** for that vendor. Don't duplicate. Currently dedicated:
  - `roles/onepassword` — 1Password
  - `roles/brave` — Brave browser
  - `roles/google_chrome` — Chrome
  - `roles/docker` — Docker CE + buildx + compose
  - `roles/github_desktop` — GitHub Desktop
  - `roles/vagrant` — Vagrant + HashiCorp repo
- **Modern uses the deprecated `apt-key` style.** All entries here MUST use the modern `signed-by=/etc/apt/keyrings/...` form. `apt-key` is removed in 24.04+.

### When to retire a dedicated role into `apt_third_party_repos`

If a per-app role is just "download key, write list file, apt install", it's a candidate for retirement. Move its repo entry to `apt_third_party_repos` and its package name to `apt_packages`, then delete the role and its line from `desktop-ubuntu.yml`. Run the playbook on a VM to confirm.

Roles that survive this test (i.e. genuinely need to stay):

- `docker` — installs key + repo + multiple packages + adds user to docker group + post-install commands
- `onepassword` — uses the .deb-direct-download install path, not an apt repo
- `vagrant` — currently a stub but the HashiCorp repo provides terraform/packer/etc., so it'll grow

## The `dotfiles` role contract

The `roles/dotfiles` role does two things: clone the dotfiles repo into `~/dotfiles`, and link **specific files** from that repo into the right locations in `$HOME`. New responsibilities can be added by extending the role with one of three patterns:

| Pattern | Use when | Example |
|---|---|---|
| Single-file symlink | One config file lives at one location | `~/.zshrc → ~/dotfiles/shell/zshrc` |
| Loop-symlink a directory | Many small files, all symlinks safe (not picked up by a binary cache) | `~/.config/autostart/*.desktop → ~/dotfiles/xdg/autostart/*` |
| Loop-copy a directory | Files need to be real (because something caches them by inode/path) | `~/.local/share/fonts/*` (fc-cache walks real files) |

The dotfiles repo currently provides:

- `xdg/autostart/` — every `.desktop` file is symlinked into `~/.config/autostart/`
- `fonts/` — every `.ttf`/`.otf` is **copied** (not symlinked) into `~/.local/share/fonts/`, then `fc-cache -f` runs
- `Templates/` — symlinked to `~/Templates` for Nautilus' right-click → New Document menu
- `shell/`, `vscode/`, `cursor/`, `ssh/`, `npm/`, `git/`, `tmux/`, `alacritty/`, `terminator/`, `nvim/`, `claude/` — direct symlinks per the dotfiles README

### Adding new managed content via dotfiles

Prefer **add files to the dotfiles repo + extend the role** over **embed files in ansible**. The dotfiles repo is yours, version-controlled, and applies on every machine. Embedding files in the ansible role couples them to the playbook and they're harder to find.

Rule of thumb: **if it's a `~/.config/<thing>/` file you'd hand-edit, it belongs in dotfiles**. If it's a system-level file (`/etc/...`), it goes in an ansible role.

## The `ubuntu_settings` (dconf) catalog

`roles/ubuntu_settings/tasks/main.yml` is the single place to capture every GNOME setting that needs to survive a reinstall. Pattern:

```yaml
- name: <human-readable description>
  community.general.dconf:
    key: '/org/gnome/<path>'
    value: '<dconf-formatted value>'
```

dconf values are **type-strict**. Common forms:

- Boolean: `'true'` / `'false'`
- Integer: `'7'`
- Unsigned: `'uint32 230'`
- String: `"'value'"` (yes, double-quoted single-quoted)
- List: `"['a', 'b']"`
- Tuple list (e.g. input sources): `"[('xkb', 'us'), ('xkb', 'es')]"`

To find the right key + value for a tweak you've made by hand:

```bash
# Watch dconf changes live while you tweak the GUI
dconf watch /

# Or dump the current state and grep:
dconf dump / > /tmp/dconf.ini
grep -B1 'my-setting' /tmp/dconf.ini
```

`scripts/audit-drift.sh` writes a full dconf dump to `/tmp/dconf-dump-<host>-<date>.ini` and reports how many keys you've captured vs the total — a rough coverage metric.

### Categories already captured

- Theme + dark mode + cursor + fonts
- Keyboard layouts (us+altgr-intl + es) + Alt+Shift toggle + caps→escape
- Workspaces (7 fixed, span all monitors)
- Hot corners off, weekday hidden in clock
- Dash-to-dock (40px icons, pinned to DP-0)
- Smart-auto-move extension config
- Nautilus (list view, hidden files, tree view, etc.)
- Custom keybinding: Super+Shift+4 → `flameshot gui --clipboard`
- Night light
- System sound off

What's intentionally NOT captured: per-app notification settings, recent-file lists, window-position state, wallpaper paths (hardware-specific), display configs.
