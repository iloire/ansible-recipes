# ansible-recipes

## Scripts and crons: single source of truth

All runnable scripts live in **`~/dotfiles/bin/`**. Nothing else.

- Do **not** bundle script copies in `roles/*/files/`.
- Do **not** install scripts to `/usr/local/bin/` (or any system path).
- The `dotfiles` role pulls `~/dotfiles` onto the host; that's how the scripts get there.
- The `crontab_server` / `crontab_desktop` roles only schedule **thin cron entries** that invoke `$HOME/dotfiles/bin/<script>`, optionally sourcing `$HOME/dotfiles/shell/local-overrides` for env vars like `WATCHDOG_API_KEY`.

Example — the only shape a watchdog cron should ever take:

```yaml
- name: send server health report to watchdog
  ansible.builtin.cron:
    name: "watchdog server health report"
    minute: "0"
    job: ". $HOME/dotfiles/shell/local-overrides; $HOME/dotfiles/bin/send-watchdog-report"
```

No `user:`, no `become:` — the cron is owned by the SSH user, not root.

### Why

Two failure modes we've hit and don't want to repeat:

1. **Drift.** A role that ships its own `files/my-script` copy goes stale the moment the dotfiles version gets updated. We caught `/usr/local/bin/send-watchdog-report` on peque still filtering mounts with a buggy `grep` months after the dotfiles copy had been fixed.
2. **Split-brain crontabs.** Running cron tasks with `become: true` puts entries in root's crontab. Mixing that with ansible-recipes (which runs as the user) produces two crontabs on the same host managed by two different repos. Hard to reason about, easy to break.

### Consequence for NAS-peque

`ansible-nas` (system-scope: docker, samba, storage) may still need root. That's fine — keep it focused on system services. **User-scope concerns (dotfiles, shell, user cron) belong to `ansible-recipes`, not to ansible-nas role overlays.** If a NAS host needs a scheduled script, add it to `crontab_server` here and target the host from this repo, don't write a bespoke role in the ansible-nas fork.
