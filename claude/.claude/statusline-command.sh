#!/usr/bin/env bash
# Claude Code statusline: shows the active model and current context-window usage.
# Reads the session JSON payload from stdin (see Claude Code statusLine docs).

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  usage_str=$(printf "%.0f%% used" "$used_pct")
else
  usage_str="no usage yet"
fi

# Dim color codes (ANSI 2 = dim/faint), reset at the end.
DIM='\033[2m'
RESET='\033[0m'

printf "${DIM}%s | %s${RESET}\n" "$model" "$usage_str"
