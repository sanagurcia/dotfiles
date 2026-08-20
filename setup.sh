#!/usr/bin/env bash
set -euo pipefail

# Resolve the repo from this script's own location: `coder dotfiles` clones
# into the coder config dir, not ~/dotfiles.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -sf "$DOTFILES/gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES/nanorc" "$HOME/.nanorc"
ln -sf "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES/ripgreprc" "$HOME/.ripgreprc"

# rg helper scripts (~/.local/bin is on PATH).
mkdir -p "$HOME/.local/bin"
for f in refs spread defs _defs fv bat-at pick; do ln -sf "$DOTFILES/bin/$f" "$HOME/.local/bin/$f"; done

# Claude Code reads user-level memory and settings from ~/.claude. Symlink them
# so this machine and the Coder workspace share one source of truth.
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
ln -sfn "$DOTFILES/claude/skills" "$HOME/.claude/skills"

# Overlay an existing ~/.zshrc — skipped where there is none.
if [ -f "$HOME/.zshrc" ]; then
	ln -sf "$DOTFILES/zshrc" "$HOME/.zshrc.local"
	if ! grep -q '\.zshrc\.local' "$HOME/.zshrc"; then
		printf '\n# personal overlay (dotfiles)\n[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"\n' >>"$HOME/.zshrc"
	fi
fi
