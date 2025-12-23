#!/bin/bash
wal -i "$1"

# Read pywal colors
source ~/.cache/wal/colors.sh

# Update Niri config with pywal colors
# Using sed to replace the focus-ring color in-place
sed -i "s/active-color \".*\" \/\/ pywal/active-color \"$color4\" \/\/ pywal/" ~/.config/niri/config.kdl

# Reload Niri config to apply new colors
niri msg action reload-config

swaymsg reload

# Kill waybar and common waybar-related processes
pkill waybar || true
pkill cava || true
pkill -f "cava.sh" || true
# Add other scripts you use with waybar here
# pkill -f "your_other_script.sh" || true

# Wait for all processes to die
while pgrep waybar > /dev/null || pgrep cava > /dev/null; do 
    sleep 0.1
done

waybar &

# This line fixes niri overview backdrop
systemctl --user restart swaybg.service
