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

# Create minimal .bashrc if missing, that sources common + local

# Configure .bashrc
if [ "$OS" = "Linux" ]; then
  BASHRC_CONTENT='
# Added by dotfiles install.sh
[ -f "$HOME/.bashrc_common" ] && . "$HOME/.bashrc_common"
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
'

  if [ ! -f "$HOME/.bashrc" ]; then
    echo "-> Creating minimal ~/.bashrc"
    echo "$BASHRC_CONTENT" > "$HOME/.bashrc"
  elif ! grep -q "bashrc_common" "$HOME/.bashrc"; then
    echo "-> Prepending to ~/.bashrc"
    temp_bash="$(mktemp)"
    echo "$BASHRC_CONTENT" > "$temp_bash"
    cat "$HOME/.bashrc" >> "$temp_bash"
    mv "$temp_bash" "$HOME/.bashrc"
  else
    echo "  = ~/.bashrc already sources common config"
  fi
fi

# Create minimal .zshrc if missing, that sources common + local

# Configure .zshrc
if [ "$OS" = "Darwin" ]; then
  ZSHRC_CONTENT='
# Added by dotfiles install.sh
[ -f "$HOME/.zshrc_common" ] && . "$HOME/.zshrc_common"
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
'

  if [ ! -f "$HOME/.zshrc" ]; then
    echo "-> Creating minimal ~/.zshrc"
    echo "$ZSHRC_CONTENT" > "$HOME/.zshrc"
  elif ! grep -q "zshrc_common" "$HOME/.zshrc"; then
    echo "-> Prepending to ~/.zshrc"
    temp_zsh="$(mktemp)"
    echo "$ZSHRC_CONTENT" > "$temp_zsh"
    cat "$HOME/.zshrc" >> "$temp_zsh"
    mv "$temp_zsh" "$HOME/.zshrc"
  else
    echo "  = ~/.zshrc already sources common config"
  fi
fi

echo "==> Done."

echo
echo "Next steps:"
echo "  - Open a new shell, or run:  source ~/.bashrc  (or ~/.zshrc)"
echo "  - Customize per-machine settings in:"
echo "        ~/.bashrc.local"
echo "        ~/.zshrc.local"
echo "        ~/.julia/config/startup_local.jl"
