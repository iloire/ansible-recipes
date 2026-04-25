#!/usr/bin/env bash
#
# test-vm.sh — robust orchestrator for testing the playbook in a Vagrant VM.
#
# Designed so a fire-and-forget background run (nohup ./scripts/test-vm.sh up &)
# either succeeds or leaves a clear record of where it failed. No silent
# bash-died-mid-pipeline mysteries.
#
# Usage:
#   ./scripts/test-vm.sh up         # vagrant up + install desktop + run full play
#   ./scripts/test-vm.sh desktop    # install ubuntu-desktop-minimal + GDM only
#   ./scripts/test-vm.sh provision  # re-run ansible only (uses ANSIBLE_TAGS env)
#   ./scripts/test-vm.sh status     # health probe + log tail
#   ./scripts/test-vm.sh halt       # gentle shutdown
#   ./scripts/test-vm.sh destroy    # remove VM (snapshots stay)
#
# Env knobs:
#   ANSIBLE_TAGS=all                # override the playbook tag set
#   ANSIBLE_VERBOSE=v|vv|vvv        # ansible -v / -vv / -vvv
#   VB_GUI=true                     # open the VirtualBox window on `up`
#
# All output is timestamped + tee'd to logs/test-vm-<UTC>.log, kept across
# runs so you can diff "last time vs this time".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
TS=$(date -u +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/test-vm-${TS}.log"
LATEST_SYMLINK="$LOG_DIR/latest.log"
ln -sfn "$(basename "$LOG_FILE")" "$LATEST_SYMLINK"

# Send stdout + stderr to the log file. When run interactively (TTY)
# also tee to the terminal so the user sees live output. When run under
# nohup/background, write directly to the file — `exec > >(tee)` looks
# clever but the tee subshell dies if the parent loses its controlling
# terminal, then SIGPIPE kills the whole script silently. Direct redirect
# survives nohup correctly. Use `tail -f $LOG_FILE` for live view.
if [ -t 1 ]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
else
  exec >> "$LOG_FILE" 2>&1
fi

log()     { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
section() { printf '\n[%s] === %s ===\n\n' "$(date -u +%H:%M:%SZ)" "$*"; }
die()     { log "ERROR: $*"; log "Full log: $LOG_FILE"; exit 1; }

cd "$REPO_ROOT"

# ---------------------------------------------------------------------
# Healthcheck — vagrant ssh with retry/backoff. Catches the failure mode
# we hit in the wild: sshd in the VM intermittently refuses connections
# during heavy package install, then recovers a few seconds later.
# ---------------------------------------------------------------------
healthcheck() {
  log "Healthcheck: probing 'vagrant ssh -c true'..."
  local i
  for i in 1 2 3 4 5 6 7 8; do
    if timeout 20 vagrant ssh -c "true" >/dev/null 2>&1; then
      log "  attempt $i: OK"
      return 0
    fi
    log "  attempt $i: failed (sleeping 8s)"
    sleep 8
  done
  die "VM unreachable via vagrant ssh after 8 attempts (~64s). Try: vagrant reload"
}

# ---------------------------------------------------------------------
# Phase 0 — bring VM up. If it doesn't exist, vagrant up will create it
# (downloads box, boots, etc). If it does, vagrant up is a no-op.
# ---------------------------------------------------------------------
cmd_boot() {
  section "Phase 0: vagrant up (boot VM, no provision)"
  vagrant up --no-provision
  healthcheck
}

# ---------------------------------------------------------------------
# Phase 1+2 — install ubuntu-desktop + GDM, then switch to graphical
# target so the VirtualBox window shows a login screen instead of TTY.
# Skipped if GDM is already active (idempotent).
# ---------------------------------------------------------------------
cmd_desktop() {
  if vagrant ssh -c "systemctl is-active gdm3" 2>/dev/null | grep -q '^active$'; then
    log "GDM already active in VM — skipping desktop install"
    return 0
  fi

  section "Phase 1: apt install ubuntu-desktop-minimal + gdm3 (~15 min)"
  vagrant ssh -c "
    set -e
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal gdm3
  "

  section "Phase 2: switch to graphical.target"
  vagrant ssh -c "
    sudo systemctl set-default graphical.target
    sudo systemctl isolate graphical.target || true   # may briefly drop SSH
  "
  sleep 10
  healthcheck
  log "GDM should now be visible in the VirtualBox window. Login: vagrant / vagrant"
}

# ---------------------------------------------------------------------
# Phase 3 — run the ansible playbook. Captures recap + first failure
# detail at the end, so the log tail is immediately useful.
# ---------------------------------------------------------------------
cmd_provision() {
  healthcheck
  local tag_label="${ANSIBLE_TAGS:-<vagrantfile-default>}"
  section "Phase 3: ansible play (tags: $tag_label, verbose: ${ANSIBLE_VERBOSE:-off})"

  local rc=0
  vagrant provision || rc=$?
  log "vagrant provision exit code: $rc"

  if [ "$rc" -ne 0 ]; then
    log ""
    log "--- failure details (last fatal/FAILED block) ---"
    grep -B1 -A8 'fatal:\|FAILED!' "$LOG_FILE" | tail -40 || true
    die "ansible play failed"
  fi

  log ""
  log "--- PLAY RECAP ---"
  grep -A2 '^PLAY RECAP' "$LOG_FILE" | tail -10 || true
}

# ---------------------------------------------------------------------
# Standalone status — for "is anything happening right now?" checks.
# ---------------------------------------------------------------------
cmd_status() {
  section "VM status"
  vagrant status 2>&1 | tail -5

  if vagrant ssh -c "true" >/dev/null 2>&1; then
    log "vagrant ssh: OK"
    log ""
    log "--- inside VM ---"
    vagrant ssh -c "
      uptime
      echo ''
      systemctl is-active gdm3 && echo 'gdm3: active' || echo 'gdm3: inactive'
      echo ''
      pgrep -af ansible-playbook | head -1 || echo 'no ansible-playbook running'
      echo ''
      tail -3 /var/log/apt/history.log 2>/dev/null | head -10
    "
  else
    log "vagrant ssh: UNREACHABLE"
  fi

  log ""
  log "--- latest test-vm log tail ---"
  ls -t "$LOG_DIR"/test-vm-*.log 2>/dev/null | head -1 | xargs -r tail -20
}

# ---------------------------------------------------------------------
# Top-level dispatch.
# ---------------------------------------------------------------------
cmd="${1:-up}"
log "test-vm.sh starting: cmd=$cmd, log=$LOG_FILE"

case "$cmd" in
  up)
    cmd_boot
    cmd_desktop
    cmd_provision
    ;;
  desktop)    cmd_desktop ;;
  provision)  cmd_provision ;;
  status)     cmd_status ;;
  halt)       vagrant halt ;;
  destroy)    vagrant destroy -f ;;
  *)
    echo "Usage: $0 {up|desktop|provision|status|halt|destroy}" >&2
    echo "  Env: ANSIBLE_TAGS=all  ANSIBLE_VERBOSE=v  VB_GUI=true" >&2
    exit 2
    ;;
esac

log ""
log "DONE. Full log: $LOG_FILE"
