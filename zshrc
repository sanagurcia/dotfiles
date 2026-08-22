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
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '%b'
precmd_functions+=(vcs_info)
setopt prompt_subst
PROMPT='%F{blue}%m%f:%F{green}%~%f:%F{yellow}${vcs_info_msg_0_}%f
%F{blue}  ❯%f '

export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export AUTARC="postgresql://postgres@127.0.0.1:54322/postgres"
export CLICOLOR=1

# Put the default alias's node on PATH without sourcing nvm's 4.8k lines (210ms);
# nvm itself loads on first use, so `nvm use` still works.
export NVM_DIR="$HOME/.nvm"
path=($HOME/.nvm/versions/node/v$(<$HOME/.nvm/alias/default)*/bin(N[-1]) $path)
nvm() { unfunction nvm; . /opt/homebrew/opt/nvm/nvm.sh; nvm "$@"; }

alias ll='ls -l' la='ls -a'
alias ssh-coder='ssh main.heiliger-space.santiago.coder'

# Ghost-text the rest of a command from history; right arrow accepts it. The
# grey is tuned for a light terminal — lower is darker.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Ctrl-R fuzzy-searches the whole history, Ctrl-T drops a file path into the
# line I am typing, Alt-C cds into a directory I pick.
eval "$(fzf --zsh)"

command -v wt >/dev/null && eval "$(wt config shell init zsh)"   # after compinit
