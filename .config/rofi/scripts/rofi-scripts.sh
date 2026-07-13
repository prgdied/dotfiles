#!/usr/bin/env bash
# rofi script-mode: lists executable scripts in ~/scripts/rofi and runs the chosen one

DIR="$HOME/scripts/rofi"

if [[ -n "$1" ]]; then
    # A selection was made — run it, detached from rofi
    setsid -f "$DIR/$1" >/dev/null 2>&1 &
    exit 0
fi

# No selection yet — list entries
for f in "$DIR"/*; do
    [[ -f "$f" && -x "$f" ]] && basename "$f"
done
