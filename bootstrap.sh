#!/usr/bin/env bash
# Clone-or-update the dotfiles repo, then run the installer.
# Safe to run repeatedly. Curl-pipe friendly:
#   curl -fsSL https://raw.githubusercontent.com/AntonOresten/dotfiles/main/bootstrap.sh | bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REPO="${DOTFILES_REPO:-https://github.com/AntonOresten/dotfiles}"

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "==> Updating dotfiles in $DOTFILES_DIR"
  git -C "$DOTFILES_DIR" pull --ff-only
else
  echo "==> Cloning dotfiles into $DOTFILES_DIR"
  git clone "$REPO" "$DOTFILES_DIR"
fi

exec "$DOTFILES_DIR/install.sh"
