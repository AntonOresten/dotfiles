# Auto-sync dotfiles on shell startup. Sourced from *rc_common.
# Expects $DOTFILES_DIR to point at the repo root.
#
# Strategy (fast + safe):
#   - foreground: if a previous fetch left us behind upstream, fast-forward
#     locally (no network) and re-run install.sh, then print one notice line.
#   - background: git fetch, throttled to once per interval, so the *next*
#     shell sees new commits. Never blocks the prompt.
#
# Skipped entirely if the working tree is dirty, so local edits are never
# clobbered. Disable with: export DOTFILES_NO_SYNC=1

__dotfiles_sync() {
  [ -n "${DOTFILES_NO_SYNC:-}" ] && return 0
  local dir="${DOTFILES_DIR:-}"
  [ -n "$dir" ] && [ -d "$dir/.git" ] || return 0
  command -v git >/dev/null 2>&1 || return 0

  # Don't touch anything if there are uncommitted changes.
  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ] && return 0

  local upstream
  upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || return 0

  # Foreground: fast-forward to whatever the last background fetch pulled in.
  local local_rev remote_rev base
  local_rev="$(git -C "$dir" rev-parse @ 2>/dev/null)" || return 0
  remote_rev="$(git -C "$dir" rev-parse '@{u}' 2>/dev/null)" || return 0
  if [ "$local_rev" != "$remote_rev" ]; then
    base="$(git -C "$dir" merge-base @ '@{u}' 2>/dev/null)"
    if [ "$base" = "$local_rev" ]; then
      if git -C "$dir" merge --ff-only --quiet '@{u}' 2>/dev/null; then
        "$dir/install.sh" >/dev/null 2>&1 || true
        printf '\033[2m[dotfiles] updated to %s — open a new shell to apply\033[0m\n' \
          "$(git -C "$dir" rev-parse --short @)"
      fi
    fi
  fi

  # Background: throttled fetch so the next shell can fast-forward.
  local stamp="$dir/.git/.dotfiles-fetch-stamp"
  local interval="${DOTFILES_SYNC_INTERVAL:-86400}"
  local now last=0
  now="$(date +%s)"
  [ -f "$stamp" ] && last="$(cat "$stamp" 2>/dev/null || echo 0)"
  if [ "$((now - last))" -ge "$interval" ]; then
    echo "$now" > "$stamp"
    ( git -C "$dir" fetch --quiet --prune origin >/dev/null 2>&1 & ) >/dev/null 2>&1
  fi
}

__dotfiles_sync
