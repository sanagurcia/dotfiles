# ~/.zshrc on this Mac; sourced as ~/.zshrc.local on Coder.

typeset -U path
path=(/opt/homebrew/bin $HOME/.local/bin /opt/homebrew/opt/libpq/bin $path $HOME/go/bin)

# Appended, not prepended: brew's git ships a wrapper around git's *bash*
# completion, which shadows zsh's own far richer _git. _git is the only overlap.
fpath=($fpath /opt/homebrew/share/zsh/site-functions)
autoload -Uz compinit && compinit

# Arrow through the candidates instead of typing more of the name, and stop
# caring about case or - vs _ while doing it.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z-}={A-Za-z_}'

# I check out local branches, not one of 2k remote ones or 2k tags. _git only
# defines _git-checkout if nobody else has, so defining it here wins. Its own
# helper is no good either: that one also offers HEAD, FETCH_HEAD and ORIG_HEAD.
_git_local_branches() {
  compadd -- ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"}
}
_git-checkout() {
  _arguments '-b[create and check out a new branch]:new branch:' \
             '*:local branch:_git_local_branches'
}

# History is how I get long commands back (Ctrl-R, !!, !$), so keep plenty of it
# and write it as I go — detached tmux sessions get killed and never exit cleanly.
HISTFILE=$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_all_dups hist_reduce_blanks hist_verify inc_append_history

# Prompt: host:cwd:branch / ❯
# Hex, not named colours: those are palette indices, so the same prompt came out
# a different colour in iTerm2 and on Coder. Fully saturated, dark enough to
# read on white.
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '%b'
precmd_functions+=(vcs_info)
setopt prompt_subst
PROMPT='%F{#0051f3}%m%f:%F{#007400}%~%f:%F{#af00af}${vcs_info_msg_0_}%f
%F{#0051f3}  ❯%f '
RPROMPT=''   # the Coder image starts starship, which leaves one on the right

export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export AUTARC="postgresql://postgres@127.0.0.1:54322/postgres"
export CLICOLOR=1

# Light or dark, once, for everything: bin/theme records it and bin/_theme hands
# it to delta, bat and the fzf previews. Ask the terminal itself at startup —
# OSC 11 is the only question that survives ssh and tmux, and it does not care
# how the theme was switched. Mid-session the iTerm2 keybinding that sends
# `theme toggle` keeps it current; asking at every prompt would put a terminal
# round trip in front of every command and race the reply against my typing.
theme detect

# The two knobs that live in this shell rather than in a script. Re-read each
# prompt — a file read, no terminal I/O — so a toggle in another pane lands here
# too. The autosuggest grey is tuned per background: lower is darker, and 245 is
# invisible on black. fzf carries no 24-bit colours of its own, so its base
# scheme is all there is to set.
_theme_apply() {
  local t=$(_theme)
  export FZF_DEFAULT_OPTS="--color=$t"
  if [[ $t == light ]]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
  else
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  fi
}
precmd_functions+=(_theme_apply)
_theme_apply

# Put the default alias's node on PATH without sourcing nvm's 4.8k lines (210ms);
# nvm itself loads on first use, so `nvm use` still works. Mac only — the Coder
# image has no nvm and brings its own node.
if [ -r $HOME/.nvm/alias/default ]; then
  export NVM_DIR="$HOME/.nvm"
  path=($NVM_DIR/versions/node/v$(<$NVM_DIR/alias/default)*/bin(N[-1]) $path)
  nvm() { unfunction nvm; . /opt/homebrew/opt/nvm/nvm.sh; nvm "$@"; }
fi

alias ll='ls -l' la='ls -a'
# Always land in a tmux session on the coder box, so I don't forget to start one.
# `ssh-coder <cmd>` still runs a one-off command; `-n <name>` picks another session.
ssh-coder() {
  local host=main.heiliger-space.santiago.coder session=coder
  [[ $1 == -n ]] && { session=$2; shift 2; }
  (( $# )) && { ssh "$host" "$@"; return; }
  ssh -t "$host" "tmux new-session -A -D -s ${(q)session}"
}

# Ghost-text the rest of a command from history; right arrow accepts it. The
# grey comes from _theme_apply above, which resets it each prompt. The Coder
# image sources its own copy before this file, so only Homebrew's needs loading
# here.
_as=/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -r $_as ] && source $_as
unset _as

# Ctrl-R fuzzy-searches the whole history, Ctrl-T drops a file path into the
# line I am typing, Alt-C cds into a directory I pick.
eval "$(fzf --zsh)"

command -v wt >/dev/null && eval "$(wt config shell init zsh)"   # after compinit
