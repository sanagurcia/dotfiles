# ~/.zshrc on this Mac; sourced as ~/.zshrc.local on Coder.

typeset -U path
path=(/opt/homebrew/bin $HOME/.local/bin /opt/homebrew/opt/libpq/bin $path $HOME/go/bin)

fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit

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

command -v wt >/dev/null && eval "$(wt config shell init zsh)"   # after compinit
