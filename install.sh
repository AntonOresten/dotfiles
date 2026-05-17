#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing dotfiles…"

# Directory where this script lives (your dotfiles repo root)
DOTFILES_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

OS="$(uname -s)"

backup() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    local backup_name="${target}.bak-$(date +%Y%m%d%H%M%S)"
    echo "  - Backing up $target -> $backup_name"
    mv "$target" "$backup_name"
  fi
}

link() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  = Link already correct: $dest"
    return
  fi
  backup "$dest"
  ln -sfn "$src" "$dest"
  echo "  + Linked $dest -> $src"
}

echo "-> Linking tmux config"
link "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"

echo "-> Linking git config"
link "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig"

echo "-> Linking shell shared config"
if [ "$OS" = "Linux" ]; then
  link "$DOTFILES_DIR/bashrc_common" "$HOME/.bashrc_common"
fi
if [ "$OS" = "Darwin" ]; then
  link "$DOTFILES_DIR/zshrc_common" "$HOME/.zshrc_common"
fi

echo "-> Linking Julia startup"
link "$DOTFILES_DIR/julia/startup.jl" "$HOME/.julia/config/startup.jl"

# --- Managed block in shell rc files -------------------------------------
# We keep only a tiny, marker-delimited stub in ~/.bashrc / ~/.zshrc that
# sources the symlinked *_common (and *.local) files. All real logic lives
# in the repo, so it auto-updates; the stub is refreshed in place on every
# install via the markers, without touching anything outside them.

MARK_BEGIN="# >>> dotfiles managed block >>>"
MARK_END="# <<< dotfiles managed block <<<"

ensure_managed_block() {
  local file="$1" body="$2"
  local block
  printf -v block '%s\n# Managed by dotfiles install.sh — do not edit between these markers.\n%s\n%s' \
    "$MARK_BEGIN" "$body" "$MARK_END"

  if [ ! -f "$file" ]; then
    echo "-> Creating $file"
    printf '%s\n' "$block" > "$file"
    return
  fi

  local bak="${file}.bak-$(date +%Y%m%d%H%M%S)"
  cp "$file" "$bak"

  if grep -qF "$MARK_BEGIN" "$file"; then
    # Refresh just the region between the markers, leave the rest untouched.
    local tmp
    tmp="$(mktemp)"
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" -v r="$block" '
      $0==b { print r; skip=1; next }
      skip && $0==e { skip=0; next }
      skip { next }
      { print }
    ' "$file" > "$tmp"
    if cmp -s "$tmp" "$file"; then
      echo "  = $file managed block already current"
      rm -f "$tmp" "$bak"
    else
      mv "$tmp" "$file"
      echo "-> Refreshed managed block in $file (backup: $bak)"
    fi
    return
  fi

  # No markers: migrate an old unmarked install (delete its injected lines),
  # then prepend the marked stub. Anything we don't recognize is preserved.
  local tmp
  tmp="$(mktemp)"
  printf '%s\n\n' "$block" > "$tmp"
  sed -E '/^# Added by dotfiles install\.sh$/,/\.local" \] && \. "/d' "$file" >> "$tmp"
  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp" "$bak"
  else
    mv "$tmp" "$file"
    echo "-> Installed managed block in $file (backup: $bak)"
  fi
}

if [ "$OS" = "Linux" ]; then
  echo "-> Configuring ~/.bashrc"
  ensure_managed_block "$HOME/.bashrc" '# Skip the rest for non-interactive shells (protects bind, prompt, etc.)
case $- in *i*) ;; *) return ;; esac
[ -f "$HOME/.bashrc_common" ] && . "$HOME/.bashrc_common"
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"'
fi

if [ "$OS" = "Darwin" ]; then
  echo "-> Configuring ~/.zshrc"
  ensure_managed_block "$HOME/.zshrc" '[ -f "$HOME/.zshrc_common" ] && . "$HOME/.zshrc_common"
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"'
fi

echo "==> Done."
echo
echo "Next steps:"
echo "  - Open a new shell, or run:  source ~/.bashrc  (or ~/.zshrc)"
echo "  - Customize per-machine settings in:"
echo "        ~/.bashrc.local"
echo "        ~/.zshrc.local"
echo "        ~/.julia/config/startup_local.jl"
