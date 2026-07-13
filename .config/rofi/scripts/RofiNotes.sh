#!/usr/bin/env bash
# Configuration
folder="$HOME/Documents/Notes/"
mkdir -p "$folder"

# Auto-detect terminal
detect_terminal() {
    if [[ -n "$TERMINAL" ]]; then
        echo "$TERMINAL"
    elif command -v foot >/dev/null 2>&1; then
        echo "foot"
    elif command -v kitty >/dev/null 2>&1; then
        echo "kitty"
    elif command -v alacritty >/dev/null 2>&1; then
        echo "alacritty -e"
    elif command -v wezterm >/dev/null 2>&1; then
        echo "wezterm start --"
    else
        notify-send "Notes Error" "No terminal found. Install kitty, foot, or alacritty."
        exit 1
    fi
}

# Launch helper: replaces swaymsg exec, works under niri (or any compositor)
launch_note() {
    local file="$1"
    local term
    term=$(detect_terminal)
    # shellcheck disable=SC2086
    setsid $term nvim "$file" >/dev/null 2>&1 &
    disown
}

# When rofi calls with no args, list options
if [[ -z "$*" ]]; then
    echo "New note (timestamp)"
    cd "$folder" || exit 1
    find . -maxdepth 1 -name "*.md" -type f -printf "%f\n" 2>/dev/null | sort -r
    exit 0
fi

# Handle selection
choice="$*"

# Special case for timestamp note
if [[ "$choice" == "New note (timestamp)" ]]; then
    name="$(date +%F_%H-%M-%S)"
    launch_note "$folder$name.md"
    exit 0
fi

# Check if the selected note exists (existing note)
if [[ -f "$folder$choice" ]]; then
    launch_note "$folder$choice"
    exit 0
fi

# Create new note with typed name
name=$(echo "$choice" | tr -d '/\\' | tr ' ' '_')
name="${name%.md}"  # Remove .md if user added it
launch_note "$folder$name.md"
exit 0
