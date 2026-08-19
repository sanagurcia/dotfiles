#!/usr/bin/env bash
set -euo pipefail

# Resolve the repo from this script's own location: `coder dotfiles` clones
# into the coder config dir, not ~/dotfiles.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -sf "$DOTFILES/gitconfig" "$HOME/.gitconfig"

# Claude Code reads user-level memory and settings from ~/.claude. Symlink them
# so this machine and the Coder workspace share one source of truth.
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
