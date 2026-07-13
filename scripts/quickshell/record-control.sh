#!/bin/bash
set -euo pipefail

STATE_DIR="$HOME/.cache/recording"

teardown_audio() {
    for f in audio_mic_mod audio_sys_mod audio_sink_mod; do
        if [[ -f "$STATE_DIR/$f" ]]; then
            pactl unload-module "$(cat "$STATE_DIR/$f")" 2>/dev/null || true
            rm -f "$STATE_DIR/$f"
        fi
    done
}

cleanup_stale_state() {
    teardown_audio
    rm -f "$STATE_DIR/pid" "$STATE_DIR/paused" "$STATE_DIR/outfile"
}

if [[ ! -f "$STATE_DIR/pid" ]]; then
    notify-send "Recording" "No active recording"
    exit 1
fi

PID=$(cat "$STATE_DIR/pid")

if ! kill -0 "$PID" 2>/dev/null; then
    cleanup_stale_state
    notify-send "Recording" "No active recording"
    exit 1
fi

case "${1:-}" in
    toggle)
        kill -SIGUSR1 "$PID"
        if [[ "$(cat "$STATE_DIR/paused" 2>/dev/null)" == "true" ]]; then
            echo "false" > "$STATE_DIR/paused"
            notify-send "Recording" "Resumed"
        else
            echo "true" > "$STATE_DIR/paused"
            notify-send "Recording" "Paused"
        fi
        ;;
    mic)
        if [[ -f "$STATE_DIR/audio_mic_mod" ]]; then
            # mic is currently feeding the recording — unload its loopback to mute it
            pactl unload-module "$(cat "$STATE_DIR/audio_mic_mod")" 2>/dev/null || true
            rm -f "$STATE_DIR/audio_mic_mod"
            notify-send "Recording" "Mic muted"
        else
            # mic is currently muted — reload the loopback to bring it back
            NEWMOD=$(pactl load-module module-loopback source=@DEFAULT_SOURCE@ sink=recording_combined)
            echo "$NEWMOD" > "$STATE_DIR/audio_mic_mod"
            notify-send "Recording" "Mic unmuted"
        fi
        ;;
    stop)
        OUTFILE=$(cat "$STATE_DIR/outfile" 2>/dev/null || echo "unknown")
        kill -SIGINT "$PID"
        # give wf-recorder a moment to finalize the mp4 before we clean up state
        sleep 1
        cleanup_stale_state
        notify-send "Recording stopped" "Saved to $OUTFILE"
        ;;
    *)
        echo "Usage: $0 {toggle|stop}"
        exit 1
        ;;
esac
