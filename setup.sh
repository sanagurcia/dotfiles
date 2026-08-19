#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/dotfiles"

ln -sf "$DOTFILES/gitconfig" "$HOME/.gitconfig"

# Claude Code reads user-level memory and settings from ~/.claude. Symlink them
# so this machine and the Coder workspace share one source of truth.
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
