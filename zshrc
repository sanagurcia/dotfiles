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

export NVM_DIR="$HOME/.nvm"
[ -s /opt/homebrew/opt/nvm/nvm.sh ] && . /opt/homebrew/opt/nvm/nvm.sh

alias ll='ls -l' la='ls -a'
alias ssh-coder='ssh main.heiliger-space.santiago.coder'

gl() {
  git log --oneline --date=short --max-count="${1:-5}" \
    --format=format:"%Cgreen%ad %Cblue%an %C(yellow)%h %Creset%s"
}

glm() {
  git log --oneline --date=short \
    --format=format:"%Cgreen%ad %Cblue%an %C(yellow)%h %Creset%s" main..HEAD
}

# Pull this repo and re-link; on Coder the clone lives in the coder config dir.
dots() {
  if [[ -d ~/dotfiles ]]; then
    git -C ~/dotfiles pull -q && ~/dotfiles/setup.sh && print -P "%F{green}✓ dotfiles%f"
  else
    coder dotfiles -y git@github.com:sanagurcia/dotfiles.git
  fi
}

command -v wt >/dev/null && eval "$(wt config shell init zsh)"   # after compinit
