#!/usr/bin/env bash

folder="$HOME/Documents/Notes/"
mkdir -p "$folder"

#!/bin/bash
if [[ -z "${RUN_FROM_FOOT:-}" ]]; then
  export RUN_FROM_FOOT=1
  exec foot -- zsh -ic "'$0'; exec zsh"
fi

# Get existing notes
cd "$folder" || exit 1
notes=$(find . -name "*.md" -type f -printf "%f\n" 2>/dev/null | sort -r)

# Build menu options
if [[ -n "$notes" ]]; then
    options="New Note\n$notes"
else
    options="New Note"
fi

# Show menu - uses your default rofi theme from config.rasi
choice=$(echo -e "$options" | rofi -dmenu -i -p "Notes:" -l 10)

case "$choice" in
    "New Note"|"")
        name=$(rofi -dmenu -p "Note name (optional):")
        [[ -z "$name" ]] && name="$(date +%F_%H-%M-%S)"
        name="${name%.md}"  # Remove .md if user added it
        $TERMINAL nvim "$folder$name.md" &
        ;;
    *.md)
        $TERMINAL nvim "$folder$choice" &
        ;;
esac
