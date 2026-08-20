# Overlay on an existing ~/.zshrc, which sources this file.

# dots — pull this repo and re-link. Quiet unless it fails; `exec zsh` to reload.
dots() {
  local out
  out=$(coder dotfiles -y git@github.com:sanagurcia/dotfiles.git 2>&1) || {
    print -r -- "$out" >&2
    return 1
  }
  print -P "%F{green}✓ Dotfiles updated%f"
}

# ripgrep reads flags only from this env var (no default path).
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
