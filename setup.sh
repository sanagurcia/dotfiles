#!/usr/bin/env bash
set -euo pipefail

# Resolve the repo from this script's own location: `coder dotfiles` clones
# into the coder config dir, not ~/dotfiles.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The zshrc, gitconfig and bin/ scripts assume these are on PATH; without them
# the shell errors on startup (fzf) or commands fail mid-run (delta, rg, ...).
REQUIRED_TOOLS=(git fzf bat delta rg fd tmux gh jq)

# Just flag what's absent — installing is left to me (brew on the Mac; the apt
# block below builds what the Coder image lacks).
missing=()
for cmd in "${REQUIRED_TOOLS[@]}"; do
	command -v "$cmd" >/dev/null || missing+=("$cmd")
done
((${#missing[@]})) && echo "Missing expected tools: ${missing[*]}" >&2

ln -sf "$DOTFILES/gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES/nanorc" "$HOME/.nanorc"
ln -sf "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES/ripgreprc" "$HOME/.ripgreprc"

mkdir -p "$HOME/.config/bat"
ln -sf "$DOTFILES/batconfig" "$HOME/.config/bat/config"

# helper scripts (~/.local/bin is on PATH).
mkdir -p "$HOME/.local/bin"
for f in "$DOTFILES"/bin/*; do ln -sf "$f" "$HOME/.local/bin/$(basename "$f")"; done

# Prune links left behind by renames in bin/.
for f in "$HOME/.local/bin"/*; do
	if [ -L "$f" ] && [ ! -e "$f" ]; then rm -f "$f"; fi
done

# nano and bat are missing from the Coder image, and /usr is wiped on rebuild.
# Install them under ~/.local instead, which lives on the home volume.
if command -v apt-get >/dev/null; then
	mkdir -p "$HOME/.local/opt"

	if [ ! -x "$HOME/.local/opt/nano/usr/bin/nano" ]; then
		ls /var/lib/apt/lists/*Packages >/dev/null 2>&1 || sudo apt-get update -qq
		tmp="$(mktemp -d)"
		(cd "$tmp" && apt-get download -qq nano && dpkg-deb -x nano_*.deb "$HOME/.local/opt/nano")
		rm -rf "$tmp"
	fi
	ln -sf "$HOME/.local/opt/nano/usr/bin/nano" "$HOME/.local/bin/nano"

	# Static upstream builds, pinned. The bat .deb wants libgit2, which the image
	# does not carry; fd is in the image, but owning it here drops that coupling.
	BAT_VERSION=0.26.1
	FD_VERSION=10.4.2

	# Version in the path, so bumping one above actually reinstalls.
	fetch_static() {
		local name=$1 version=$2 url=$3
		local dir="$HOME/.local/opt/$name-$version"
		if [ ! -x "$dir/$name" ]; then
			mkdir -p "$dir"
			curl -fsSL "$url" | tar xz -C "$dir" --strip-components=1
		fi
		ln -sf "$dir/$name" "$HOME/.local/bin/$name"
	}

	fetch_static bat "$BAT_VERSION" "https://github.com/sharkdp/bat/releases/download/v$BAT_VERSION/bat-v$BAT_VERSION-x86_64-unknown-linux-musl.tar.gz"
	fetch_static fd "$FD_VERSION" "https://github.com/sharkdp/fd/releases/download/v$FD_VERSION/fd-v$FD_VERSION-x86_64-unknown-linux-musl.tar.gz"
fi

# iTerm2 (macOS only). Dynamic profiles are read from this directory and never
# written back, so the profile can live here; iTerm2 re-reads it on change.
if [ "$(uname -s)" = Darwin ]; then
	ITERM_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
	mkdir -p "$ITERM_DIR"
	ln -sf "$DOTFILES/iterm2/profile.json" "$ITERM_DIR/dotfiles.json"

	# Making it the default writes to iTerm2's own plist, which iTerm2 rewrites
	# from memory when it quits — so only worth doing while it is closed.
	if pgrep -xq iTerm2; then
		echo "iTerm2 running: quit it and re-run to set the dotfiles profile as default." >&2
	else
		defaults write com.googlecode.iterm2 "Default Bookmark Guid" \
			-string "$(jq -r '.Profiles[0].Guid' "$DOTFILES/iterm2/profile.json")"
	fi
fi

# Claude Code reads user-level memory and settings from ~/.claude. Symlink them
# so this machine and the Coder workspace share one source of truth.
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$DOTFILES/claude/statusline.sh" "$HOME/.claude/statusline.sh"
ln -sfn "$DOTFILES/claude/skills" "$HOME/.claude/skills"

# Own ~/.zshrc where there is none (this Mac); overlay one we did not write (Coder).
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
	ln -sf "$DOTFILES/zshrc" "$HOME/.zshrc.local"
	if ! grep -q '\.zshrc\.local' "$HOME/.zshrc"; then
		printf '\n# personal overlay (dotfiles)\n[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"\n' >>"$HOME/.zshrc"
	fi
else
	ln -sf "$DOTFILES/zshrc" "$HOME/.zshrc"
fi
