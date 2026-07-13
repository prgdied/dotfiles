#!/usr/bin/env bash

# ── Config ────────────────────────────────────────────────────────────────────
WALL_DIR="$HOME/Pictures/Wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
THUMB_SIZE="480x270"

BACKEND="${WALLPAPER_BACKEND:-awww}"
MODE="${1:-shallow}"

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$THUMB_DIR"

# ── Wait for awww daemon ───────────────────────────────────────────────────────
wait_for_awww() {
    local tries=0
    while ! awww query &>/dev/null; do
        sleep 0.5
        tries=$((tries + 1))
        if [ $tries -ge 20 ]; then
            echo "select-wallpaper: timed out waiting for awww daemon" >&2
            return 1
        fi
    done
    return 0
}

# ── Thumbnail generation ───────────────────────────────────────────────────────
get_thumb() {
    local src="$1"
    local hash
    hash=$(echo "$src" | md5sum | cut -d' ' -f1)
    local thumb="$THUMB_DIR/${hash}.png"

    if [ ! -f "$thumb" ]; then
        magick "${src}[0]" \
            -resize "${THUMB_SIZE}^" \
            -gravity Center \
            -extent "$THUMB_SIZE" \
            "$thumb" 2>/dev/null
    fi

    echo "$thumb"
}

# ── Wallpaper listing ──────────────────────────────────────────────────────────
list_wallpapers() {
    local find_args=("$WALL_DIR")

    if [ "$MODE" = "shallow" ]; then
        find_args+=(-maxdepth 1)
    fi

    find "${find_args[@]}" -type f \( \
        -iname "*.jpg" \
        -o -iname "*.jpeg" \
        -o -iname "*.png" \
        -o -iname "*.webp" \
        -o -iname "*.gif" \
    \) | sort | while read -r path; do
        local thumb
        thumb=$(get_thumb "$path")
        printf '%s\0icon\x1f%s\n' "$path" "$thumb"
    done
}

# ── Recache helper ─────────────────────────────────────────────────────────────
recache() {
    rm -rf "$THUMB_DIR"
    mkdir -p "$THUMB_DIR"
    notify-send "Wallpaper Switcher" "Cache cleared — reopen to reload." 2>/dev/null || true
}

# ── Apply wallpaper ────────────────────────────────────────────────────────────
apply_wallpaper() {
    local path="$1"
    local transition="${2:-wipe}"

    case "$BACKEND" in
        awww)
            local outputs
            outputs=$(awww query 2>/dev/null | grep -oP '^: \K[^:]+' | tr -d ' ')

            if [ -z "$outputs" ]; then
                awww img "$path" \
                    --transition-type "$transition" \
                    --transition-fps 60 \
                    --transition-duration 0.9
            else
                while IFS= read -r output; do
                    awww img "$path" \
                        --outputs "$output" \
                        --transition-type "$transition" \
                        --transition-fps 60 \
                        --transition-duration 0.9 &
                done <<< "$outputs"
                wait
            fi
            ;;
        swww)
            swww img "$path" \
                --transition-type wipe \
                --transition-fps 60 \
                --transition-duration 0.9
            ;;
        swaybg)    pkill swaybg; swaybg -i "$path" -m fill & ;;
        feh)       feh --bg-fill "$path" ;;
        hyprpaper) hyprctl hyprpaper wallpaper ",$path" ;;
        mpvpaper)  pkill mpvpaper; mpvpaper -o "no-audio loop" '*' "$path" & ;;
        wallutils) setwallpaper "$path" ;;
        *)         awww img "$path" --transition-type wipe --transition-fps 60 ;;
    esac
}

# ── Reload pywal-dependent apps ───────────────────────────────────────────────
reload_theme() {
    true
}

# ── apply-qs ──────────────────────────────────────────────────────────────────
if [ "$1" = "apply-qs" ]; then
    path="$2"
    if [ -f "$path" ]; then
        apply_wallpaper "$path" "wipe"
        wal -q -t -n -i "$path"
        reload_theme
    fi
    exit 0
fi

# ── Restore ───────────────────────────────────────────────────────────────────
if [ "$1" = "restore" ]; then
    last="$HOME/.cache/wal/wal"
    if [ -f "$last" ]; then
        path=$(cat "$last")
        if [ -f "$path" ]; then
            if [ "$BACKEND" = "awww" ] || [ "$BACKEND" = "swww" ]; then
                wait_for_awww || exit 1
            fi
            apply_wallpaper "$path" "none"
            wal -q -t -n -i "$path"
            reload_theme
        fi
    fi
    exit 0
fi

# ── Random ────────────────────────────────────────────────────────────────────
if [ "$1" = "random" ]; then
    random_pick=$(find "$WALL_DIR" -maxdepth 1 -type f \( \
        -iname "*.jpg" \
        -o -iname "*.jpeg" \
        -o -iname "*.png" \
        -o -iname "*.webp" \
        -o -iname "*.gif" \
    \) | shuf -n 1)

    if [ -f "$random_pick" ]; then
		echo "$random_pick"
        apply_wallpaper "$random_pick" "wipe"
        wal -q -t -n -i "$random_pick"
        reload_theme
    fi
    exit 0
fi

# ── Precache ──────────────────────────────────────────────────────────────────
if [ "$1" = "precache" ]; then
    find "$WALL_DIR" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" \
        -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \
    \) | while read -r path; do
        get_thumb "$path" > /dev/null
    done
    exit 0
fi
