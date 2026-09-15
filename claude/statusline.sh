#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract model display name (e.g., "Claude 3.5 Sonnet" -> "sonnet", "Opus 5 (1M context)" -> "opus")
# Drop parenthetical suffixes and "Claude", strip version numbers, keep the last remaining word
model=$(echo "$input" | jq -r '.model.display_name' | sed 's/([^)]*)//g' | sed 's/Claude //i' | sed 's/[0-9][0-9.]*//g' | awk '{print tolower($NF)}')

# Extract username
username=$(whoami)

# Extract current directory and replace home with ~
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
current_dir_display="${current_dir/#$HOME/~}"

# Current git branch, if we're inside a repo (detached HEAD falls back to a short SHA)
branch=$(git -C "$current_dir" symbolic-ref --quiet --short HEAD 2>/dev/null \
    || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)

# Extract token usage
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

# Percentage: prefer Claude Code's pre-calculated value, fall back to our own
percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
total_used=$((total_input + total_output))
if [ -z "$percentage" ]; then
    if [ "$context_size" -gt 0 ]; then
        percentage=$((total_used * 100 / context_size))
    else
        percentage=0
    fi
fi

# Format token usage (e.g., 50k/200k)
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000 ]; then
        echo "$((num / 1000))k"
    else
        echo "$num"
    fi
}

used_display=$(format_tokens $total_used)
size_display=$(format_tokens $context_size)

# Build a 10-cell progress bar
bar_width=10
filled=$((percentage * bar_width / 100))
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
[ "$filled" -lt 0 ] && filled=0
empty=$((bar_width - filled))
bar=""
[ "$filled" -gt 0 ] && bar=$(printf '█%.0s' $(seq 1 $filled))
[ "$empty" -gt 0 ] && bar+=$(printf '░%.0s' $(seq 1 $empty))

# Line 1: <model> <user>:<currentPath> [branch]   (purple model, green user, blue path, cyan branch)
printf "\033[35m%s\033[0m \033[32m%s\033[0m:\033[34m%s\033[0m" \
    "$model" "$username" "$current_dir_display"
[ -n "$branch" ] && printf " \033[36m(%s)\033[0m" "$branch"
printf "\n"

# Line 2: token usage + bar, so a long path can never push it off screen
printf "\033[33m%s/%s (%s%%) %s\033[0m\n" \
    "$used_display" "$size_display" "$percentage" "$bar"
