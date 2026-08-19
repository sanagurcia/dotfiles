# Personal zsh overlay, sourced from ~/.zshrc.
#
# The Coder workspace's own ~/.zshrc comes from the image skel and is maintained
# with the image, so it stays unmanaged here and this file is layered on top.

# fv — fuzzy-find a file by name, preview it, page the pick through bat.
# Needs fd, fzf and bat.
fv() {
  fd -t f "$1" | fzf --preview 'bat --color=always {}' --preview-window=right:60%:border | xargs -r bat --color=always --paging=always
}
