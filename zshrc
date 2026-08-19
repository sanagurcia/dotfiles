# Overlay on an existing ~/.zshrc, which sources this file.

# fv — fuzzy-find a file, preview it, page the pick. Needs fd, fzf, bat.
fv() {
  fd -t f "$1" | fzf --preview 'bat --color=always {}' --preview-window=right:60%:border | xargs -r bat --color=always --paging=always
}

# dots — pull this repo and re-link. Quiet unless it fails; `exec zsh` to reload.
dots() {
  local out
  out=$(coder dotfiles -y git@github.com:sanagurcia/dotfiles.git 2>&1) || {
    print -r -- "$out" >&2
    return 1
  }
  print -P "%F{green}✓ Dotfiles updated%f"
}
