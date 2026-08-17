#!/usr/bin/env bash

ln -sf "$HOME/dotfiles/gitconfig" "$HOME/.gitconfig"
mkdir -p "$HOME/.config/lazygit"
ln -sf "$HOME/dotfiles/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"