# Overlay on an existing ~/.zshrc, which sources this file.

# fv — fuzzy-find a file, preview it, page the pick. Needs fd, fzf, bat.
fv() {
  fd -t f "$1" | fzf --preview 'bat --color=always {}' --preview-window=right:60%:border | xargs -r bat --color=always --paging=always
}
