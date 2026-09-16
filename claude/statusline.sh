#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract model display name (e.g., "Claude 3.5 Sonnet" -> "sonnet", "Opus 5 (1M context)" -> "opus")
# Drop parenthetical suffixes and "Claude", strip version numbers, keep the last remaining word
model=$(echo "$input" | jq -r '.model.display_name' | sed 's/([^)]*)//g' | sed 's/Claude //i' | sed 's/[0-9][0-9.]*//g' | awk '{print tolower($NF)}')

# Effort level, when the model has one ("medium" -> "med", the rest as-is)
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ "$effort" = "medium" ] && effort="med"

# Extract username
username=$(whoami)

# Extract current directory and replace home with ~
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
current_dir_display="${current_dir/#$HOME/~}"

# Current git branch, if we're inside a repo (detached HEAD falls back to a short SHA)
branch=$(git -C "$current_dir" symbolic-ref --quiet --short HEAD 2>/dev/null \
    || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)

# <model>[:effort] <user>:<currentPath> [branch]   (purple model, green user, blue path, cyan branch)
printf "\033[35m%s\033[0m" "$model"
[ -n "$effort" ] && printf "\033[35m:%s\033[0m" "$effort"
printf " \033[32m%s\033[0m:\033[34m%s\033[0m" "$username" "$current_dir_display"
[ -n "$branch" ] && printf " \033[36m(%s)\033[0m" "$branch"
printf "\n"
