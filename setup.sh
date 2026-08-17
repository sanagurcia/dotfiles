#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/dotfiles"

ln -sf "$DOTFILES/gitconfig" "$HOME/.gitconfig"

# lazygit's config dir is OS-dependent (~/Library/Application Support on macOS,
# ~/.config on Linux), so ask lazygit instead of hardcoding a path.
if command -v lazygit >/dev/null 2>&1; then
	LAZYGIT_DIR="$(lazygit --print-config-dir)"
	mkdir -p "$LAZYGIT_DIR"
	ln -sf "$DOTFILES/lazygit-config.yml" "$LAZYGIT_DIR/config.yml"
else
	echo "setup.sh: lazygit not installed, skipping its config" >&2
fi
