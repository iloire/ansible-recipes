#!/usr/bin/env bash
#
# audit-drift.sh — compare current system state against ansible-recipes
# to find what's installed/configured on the machine but NOT captured
# in the playbook. Run this on a working machine to discover gaps
# BEFORE you reinstall / upgrade, so the Ansible run covers them next time.
#
# Usage:
#   ./scripts/audit-drift.sh                  # print report to stdout
#   ./scripts/audit-drift.sh > report.md      # save report
#
# Safe: read-only. Queries the system + greps the repo. No changes made.
#
# Supported platforms: Linux (Ubuntu/Debian). Bails on macOS.

set -euo pipefail

# Resolve repo root (one level up from this script's dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINUX_VARS="$REPO_ROOT/group_vars/linux.yml"
ROLES_DIR="$REPO_ROOT/roles"

# Platform guard
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script only runs on Linux (needs apt/snap/flatpak/dconf)." >&2
  exit 1
fi

HOST="$(hostname)"
DATE="$(date -u +%Y-%m-%d)"
DISTRO="$(lsb_release -ds 2>/dev/null || echo unknown)"

# Helpers --------------------------------------------------------------

# Extract a YAML list variable from group_vars/linux.yml
# Usage: yaml_list apt_packages
yaml_list() {
  local var="$1"
  awk -v v="^${var}:" '
    $0 ~ v { cap=1; next }
    cap && /^[a-z_]+:/ { cap=0 }
    cap && /^ *- / { sub(/^ *- */, ""); gsub(/"/, ""); print }
  ' "$LINUX_VARS" | sort -u
}

# Print a diff: lines in stdin that are NOT in the given "known" list.
# Usage: command | diff_against "known1 known2 ..."
diff_against() {
  local known="$1"
  grep -vxFf <(printf '%s\n' $known | sort -u) | sort -u
}

section() {
  printf '\n## %s\n\n' "$1"
}

subsection() {
  printf '\n### %s\n\n' "$1"
}

count_lines() {
  wc -l | awk '{print $1}'
}

# Header ---------------------------------------------------------------

cat <<EOF
# Ansible drift audit — ${HOST}

**Date:** ${DATE} (UTC)
**Host:** ${HOST}
**Distro:** ${DISTRO}
**Repo:** ${REPO_ROOT}

Everything listed below is **present on this machine but not found in ansible-recipes**.
Action items: add them to the corresponding role/vars, OR mark explicitly as "manual step".
EOF

# ---------------------------------------------------------------------
# 1. apt packages
# ---------------------------------------------------------------------
section "apt packages — manually installed but not in ansible vars"

apt_known="$(yaml_list apt_minimum_packages; yaml_list apt_packages)"
# Packages from a typical Ubuntu base seed that we expect to be installed
# but don't want cluttering the drift report. Keep conservative — too long
# a filter hides real drift.
apt_base_noise="$(cat <<'NOISE'
ubuntu-desktop
ubuntu-desktop-minimal
ubuntu-standard
ubuntu-minimal
linux-generic
linux-image-generic
linux-headers-generic
firefox
snapd
gnome-shell
gdm3
NOISE
)"

apt_drift=$(
  apt-mark showmanual 2>/dev/null \
    | diff_against "$apt_known $apt_base_noise"
)

if [[ -z "$apt_drift" ]]; then
  echo "_No drift detected._"
else
  echo "$apt_drift" | awk '{printf "- `%s`\n", $0}'
  count=$(echo "$apt_drift" | count_lines)
  echo
  echo "**Total: $count packages.** Add the ones you want to keep to \`group_vars/linux.yml\` under \`apt_packages\`."
fi

# ---------------------------------------------------------------------
# 2. snap packages
# ---------------------------------------------------------------------
section "snap packages"

if command -v snap >/dev/null 2>&1; then
  snap_known="$(yaml_list snap_packages; yaml_list snap_classic_packages)"
  snap_base_noise="core core18 core20 core22 core24 snapd bare gtk-common-themes gnome-42-2204 gnome-3-38-2004 firefox"

  snap_drift=$(
    snap list 2>/dev/null | awk 'NR>1 {print $1}' \
      | diff_against "$snap_known $snap_base_noise"
  )

  if [[ -z "$snap_drift" ]]; then
    echo "_No drift detected._"
  else
    echo "$snap_drift" | awk '{printf "- `%s`\n", $0}'
    echo
    echo "Add to \`snap_packages\` (strict) or \`snap_classic_packages\` (classic confinement)."
  fi
else
  echo "_snap not installed._"
fi

# ---------------------------------------------------------------------
# 3. flatpak apps
# ---------------------------------------------------------------------
section "flatpak apps"

if command -v flatpak >/dev/null 2>&1; then
  flatpak_known="$(yaml_list flatpak_packages)"
  flatpak_drift=$(
    flatpak list --app --columns=application 2>/dev/null \
      | diff_against "$flatpak_known"
  )

  if [[ -z "$flatpak_drift" ]]; then
    echo "_No drift detected._"
  else
    echo "$flatpak_drift" | awk '{printf "- `%s`\n", $0}'
    echo
    echo "Add to \`flatpak_packages\` in \`group_vars/linux.yml\`."
  fi
else
  echo "_flatpak not installed._"
fi

# ---------------------------------------------------------------------
# 4. VS Code extensions (not currently managed by ansible)
# ---------------------------------------------------------------------
section "VS Code extensions (role \`vscode_config\` currently only syncs settings.json — extensions are drift)"

if command -v code >/dev/null 2>&1; then
  ext_list=$(code --list-extensions 2>/dev/null || true)
  if [[ -z "$ext_list" ]]; then
    echo "_No extensions found._"
  else
    echo "$ext_list" | awk '{printf "- `%s`\n", $0}'
    count=$(echo "$ext_list" | count_lines)
    echo
    echo "**Total: $count extensions.** Suggest: add a \`vscode_extensions\` var + an install loop in the \`vscode_config\` role:"
    echo
    echo '```yaml'
    echo '- name: Install VS Code extensions'
    echo '  shell: code --install-extension {{ item }}'
    echo '  loop: "{{ vscode_extensions }}"'
    echo '  changed_when: false'
    echo '```'
  fi
else
  echo "_\`code\` CLI not available._"
fi

# ---------------------------------------------------------------------
# 5. GNOME shell extensions (not currently managed)
# ---------------------------------------------------------------------
section "GNOME shell extensions (not managed by ansible)"

if command -v gnome-extensions >/dev/null 2>&1; then
  gnome_enabled=$(gnome-extensions list --enabled 2>/dev/null || true)
  if [[ -z "$gnome_enabled" ]]; then
    echo "_No enabled extensions._"
  else
    echo "$gnome_enabled" | awk '{printf "- `%s`\n", $0}'
    echo
    echo "Suggest: create a \`gnome_extensions\` role that \`gext\` or \`gnome-extensions-cli\` installs from a list."
  fi
else
  echo "_\`gnome-extensions\` CLI not available._"
fi

# ---------------------------------------------------------------------
# 6. systemd user services
# ---------------------------------------------------------------------
section "systemd user services (enabled)"

sys_user=$(
  systemctl --user list-unit-files --state=enabled --no-pager --no-legend 2>/dev/null \
    | awk '{print $1}' \
    | grep -vE '^(default\.target|timers\.target|sockets\.target)$' || true
)

if [[ -z "$sys_user" ]]; then
  echo "_No enabled user services._"
else
  echo "$sys_user" | awk '{printf "- `%s`\n", $0}'
  echo
  echo "Review: should these live in the \`autostart\` role, or a new \`systemd_user_services\` role?"
fi

# ---------------------------------------------------------------------
# 7. Crontab (user)
# ---------------------------------------------------------------------
section "Crontab (user) vs roles/crontab_desktop + roles/crontab_server"

user_cron=$(crontab -l 2>/dev/null | grep -vE '^\s*#|^\s*$' || true)
if [[ -z "$user_cron" ]]; then
  echo "_Empty crontab._"
else
  echo '```cron'
  echo "$user_cron"
  echo '```'
  echo
  echo "Compare against:"
  echo "- \`$ROLES_DIR/crontab_desktop/\`"
  echo "- \`$ROLES_DIR/crontab_server/\`"
  echo "Add any missing entries to the appropriate role template."
fi

# ---------------------------------------------------------------------
# 8. User groups
# ---------------------------------------------------------------------
section "User groups (look for non-default memberships)"

current_groups=$(id -Gn "$USER" | tr ' ' '\n' | sort -u)
# Default groups a fresh Ubuntu user is typically in.
default_groups="$(cat <<'DEF'
adm
audio
cdrom
dialout
dip
floppy
lpadmin
netdev
plugdev
sambashare
sudo
tape
users
video
DEF
)"

group_drift=$(echo "$current_groups" | diff_against "$default_groups $USER")

echo '```'
echo "Current groups: $(id -Gn "$USER")"
echo '```'
if [[ -n "$group_drift" ]]; then
  echo
  echo "Non-default / notable groups (may need explicit \`user: groups=\` in ansible):"
  echo "$group_drift" | awk '{printf "- `%s`\n", $0}'
fi

# ---------------------------------------------------------------------
# 9. /etc/fstab (manual mounts)
# ---------------------------------------------------------------------
section "/etc/fstab custom entries (beyond / and swap)"

fstab_drift=$(
  grep -vE '^\s*#|^\s*$' /etc/fstab 2>/dev/null \
    | awk '$2 != "/" && $2 != "none" && $2 != "/boot/efi"' \
    || true
)

if [[ -z "$fstab_drift" ]]; then
  echo "_No custom mounts._"
else
  echo '```fstab'
  echo "$fstab_drift"
  echo '```'
  echo
  echo "These mounts are machine-specific. Consider adding an \`ansible.posix.mount\` task to a host-specific playbook or a \`fstab\` role."
fi

# ---------------------------------------------------------------------
# 10. dconf dump size (GNOME settings)
# ---------------------------------------------------------------------
section "dconf (GNOME settings) — size of dump vs what's captured by \`ubuntu_settings\`"

if command -v dconf >/dev/null 2>&1; then
  dconf_dump_file="/tmp/dconf-dump-${HOST}-${DATE}.ini"
  dconf dump / > "$dconf_dump_file" 2>/dev/null || true
  dconf_lines=$(wc -l < "$dconf_dump_file")
  dconf_keys=$(grep -cE '^[a-z-]+=' "$dconf_dump_file" || true)

  ansible_dconf_keys=$(
    grep -rhoE 'key: *["'"'"']?/[^"'"'"']+' "$ROLES_DIR" 2>/dev/null \
      | sed -E 's/^key: *["'"'"']?//' \
      | sort -u \
      | wc -l
  )

  echo "- Full dconf dump: **${dconf_lines} lines / ~${dconf_keys} keys** (saved to \`${dconf_dump_file}\`)"
  echo "- Keys currently captured in ansible roles (via \`dconf:\` tasks): **${ansible_dconf_keys}**"
  echo
  echo "Coverage is partial by design — not every GNOME tweak is worth ansibling. Suggested focus:"
  echo "- Keyboard shortcuts (\`/org/gnome/settings-daemon/plugins/media-keys/*\`, \`/org/gnome/desktop/wm/keybindings/*\`)"
  echo "- Window manager behavior (\`/org/gnome/mutter/*\`, \`/org/gnome/desktop/wm/preferences/*\`)"
  echo "- Dash-to-dock / dock preferences"
  echo "- Any custom keybindings you rely on daily"
  echo
  echo "Review the dump file, copy the keys you care about into the \`ubuntu_settings\` role."
else
  echo "_\`dconf\` not available._"
fi

# ---------------------------------------------------------------------
# 11. Known hardcoded gotchas
# ---------------------------------------------------------------------
section "Known hardcoded gotchas in the playbook"

echo "Things already in \`group_vars/linux.yml\` that **will break on a new Ubuntu release** and need manual review:"
echo
grep -nE "(nvidia-driver-[0-9]+|python3\.[0-9]+|libfuse[0-9]+)" "$LINUX_VARS" 2>/dev/null \
  | awk -F: '{printf "- `%s:%s` — `%s`\n", "group_vars/linux.yml", $1, $3}' \
  || echo "_None found._"

# ---------------------------------------------------------------------
# 12. Bootstrap / auth steps that can't be automated
# ---------------------------------------------------------------------
section "Manual bootstrap checklist (can't be fully ansibled)"

cat <<'EOF'
These genuinely require a human on install day. Keep them in a "Day 1 runbook":

- [ ] Restore SSH keys: `~/.ssh/` from backup + `chmod 600 ~/.ssh/id_*`
- [ ] Restore GPG keys: `gpg --import <keyfile>`
- [ ] Restore `~/git-crypt-key` → unlock repos with `git-crypt unlock`
- [ ] Sign in to 1Password (Emergency Kit + account password)
- [ ] Tailscale: `sudo tailscale up` (interactive auth or pre-auth key)
- [ ] NVIDIA proprietary driver: `ubuntu-drivers autoinstall` → reboot → verify `nvidia-smi`
- [ ] Mount / verify 4TB DATA drive by UUID, not device letter
- [ ] Chrome / Firefox sign-in (covers bookmarks + passwords via sync)
- [ ] Git config user identity verified (should come from dotfiles, but double-check)
- [ ] Docker: add user to docker group, `newgrp docker`, verify `docker run hello-world`
EOF

# ---------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------
echo
echo "---"
echo
echo "_Generated by \`scripts/audit-drift.sh\` on ${DATE}._"
