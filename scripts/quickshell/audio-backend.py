#!/usr/bin/env python3
import sys
import json
import subprocess
import threading
import time
import traceback

def log_error(msg):
    sys.stderr.write(f"[Audio Backend Error]: {msg}\n")
    sys.stderr.flush()

# emit_state() is called from the stdin command loop AND from both listener
# threads (listen_pactl, listen_mpris) concurrently. print() does its write
# and its trailing newline as two separate syscalls, so without a lock two
# threads can interleave mid-line and hand the frontend a garbled/concatenated
# JSON line, which the QML side silently drops - looking like "nothing updates".
_stdout_lock = threading.Lock()

# Player currently being displayed/controlled, updated on every get_mpris() call.
# Used to route play/pause/next/previous/seek commands to the player actually
# shown in the UI instead of whatever playerctl's own "default" happens to be.
_last_target_player = None

MPRIS_FORMAT = "\x1f".join([
    "{{playerName}}", "{{status}}", "{{title}}", "{{artist}}",
    "{{album}}", "{{mpris:artUrl}}", "{{position}}", "{{mpris:length}}"
])

def get_mpris():
    global _last_target_player

    # Single atomic call across all players instead of N+1 separate subprocess
    # calls (playerctl -l, then a status call per player, then metadata/position/
    # length calls per player). The old approach was racy: if a per-player status
    # check happened to fail or land mid-transition, the priority loop would
    # silently skip a genuinely-Playing player and fall back to a Paused one
    # (this is what caused Feishin to "take over" from Navidrome).
    try:
        raw = subprocess.check_output(
            ["playerctl", "-a", "metadata", "--format", MPRIS_FORMAT],
            text=True, stderr=subprocess.DEVNULL
        )
        lines = [l for l in raw.splitlines() if l.strip()]
    except Exception:
        lines = []

    entries = []
    for line in lines:
        parts = line.split("\x1f")
        if len(parts) < 8:
            continue
        name, status, title, artist, album, art, pos, length = parts[:8]
        # {{position}} / {{mpris:length}} format tokens are microseconds
        # (unlike the bare `playerctl position` subcommand, which is seconds)
        try:
            position = float(pos) / 1000000.0 if pos else 0.0
        except ValueError:
            position = 0.0
        try:
            length_s = float(length) / 1000000.0 if length else 0.0
        except ValueError:
            length_s = 0.0
        entries.append({
            "player": name,
            "status": status,
            "title": title,
            "artist": artist,
            "album": album,
            "art": art,
            "position": position,
            "length": length_s
        })

    # Priority 1: whichever player is actively "Playing"
    target = None
    for e in entries:
        if e["status"] == "Playing":
            target = e
            break

    # Priority 2: fall back to a "Paused" player
    if not target:
        for e in entries:
            if e["status"] == "Paused":
                target = e
                break

    # Priority 3: fall back to the first player in the list
    if not target and entries:
        target = entries[0]

    _last_target_player = target["player"] if target else None

    if not target:
        return {
            "title": "No Media Playing", "artist": "Unknown Artist", "album": "",
            "art": "", "status": "Stopped", "position": 0.0, "length": 0.0
        }

    return {
        "title": target["title"] or "No Media Playing",
        "artist": target["artist"] or "Unknown Artist",
        "album": target["album"] or "",
        "art": target["art"],
        "status": target["status"] or "Stopped",
        "position": target["position"],
        "length": target["length"]
    }


def _volume_and_db(entry):
    vol_pct = 0
    db_val = "0.00 dB"
    if entry.get("volume"):
        first_ch = list(entry["volume"].values())[0]
        vol_pct = int(first_ch.get("value_percent", "0%").replace("%", ""))
        db_val = first_ch.get("db", "0.00 dB")
    return vol_pct, db_val


def get_pactl():
    try:
        raw = subprocess.check_output(["pactl", "-f", "json", "list"], text=True, stderr=subprocess.DEVNULL)
        data = json.loads(raw)
    except Exception as e:
        log_error(f"pactl failed to retrieve or parse: {e}")
        return {}

    try:
        default_sink = subprocess.check_output(["pactl", "get-default-sink"], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        default_sink = ""
    try:
        default_source = subprocess.check_output(["pactl", "get-default-source"], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        default_source = ""

    sinks = []
    for s in data.get("sinks", []):
        vol_pct, db_val = _volume_and_db(s)
        ports = [{"name": p.get("name"), "description": p.get("description")} for p in s.get("ports", [])]
        sinks.append({
            "id": s.get("index"),
            "name": s.get("name"),
            "description": s.get("description") or s.get("name"),
            "volume": vol_pct,
            "db": db_val,
            "mute": s.get("mute", False),
            "active_port": s.get("active_port"),
            "ports": ports,
            "is_default": s.get("name") == default_sink
        })

    sources = []
    for s in data.get("sources", []):
        vol_pct, db_val = _volume_and_db(s)
        ports = [{"name": p.get("name"), "description": p.get("description")} for p in s.get("ports", [])]
        sources.append({
            "id": s.get("index"),
            "name": s.get("name"),
            "description": s.get("description") or s.get("name"),
            "volume": vol_pct,
            "db": db_val,
            "mute": s.get("mute", False),
            "active_port": s.get("active_port"),
            "ports": ports,
            "is_default": s.get("name") == default_source,
            "is_monitor": ".monitor" in s.get("name", "")
        })

    playback = []
    for si in data.get("sink_inputs", []):
        vol_pct, db_val = _volume_and_db(si)
        props = si.get("properties", {})
        name = props.get("application.name") or props.get("media.name") or f"Stream {si.get('index')}"
        playback.append({
            "id": si.get("index"),
            "name": name,
            "volume": vol_pct,
            "db": db_val,
            "mute": si.get("mute", False)
        })

    recording = []
    for so in data.get("source_outputs", []):
        vol_pct, db_val = _volume_and_db(so)
        props = so.get("properties", {})
        name = props.get("application.name") or props.get("media.name") or f"Stream {so.get('index')}"
        recording.append({
            "id": so.get("index"),
            "name": name,
            "volume": vol_pct,
            "db": db_val,
            "mute": so.get("mute", False)
        })

    cards = []
    for c in data.get("cards", []):
        profiles = [{"name": name, "description": val.get("description") or name} for name, val in c.get("profiles", {}).items()]
        props = c.get("properties", {})
        cards.append({
            "id": c.get("index"),
            "name": c.get("name"),
            "description": props.get("device.description") or c.get("name"),
            "active_profile": c.get("active_profile"),
            "profiles": profiles
        })

    return {
        "sinks": sinks,
        "sources": [s for s in sources if not s["is_monitor"]],
        "playback": playback,
        "recording": recording,
        "cards": cards
    }


def emit_state():
    try:
        state = {
            "mpris": get_mpris(),
            "audio": get_pactl()
        }
        line = json.dumps(state)
        with _stdout_lock:
            print(line, flush=True)
    except Exception as e:
        log_error(f"Failed to emit state: {e}")


def listen_pactl():
    try:
        proc = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE, text=True, stderr=subprocess.DEVNULL)
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            emit_state()
    except Exception as e:
        log_error(f"pactl subscribe thread died: {e}")


def listen_mpris():
    try:
        proc = subprocess.Popen(["playerctl", "-F", "metadata", "--format", "change"], stdout=subprocess.PIPE, text=True, stderr=subprocess.DEVNULL)
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            emit_state()
    except Exception as e:
        log_error(f"playerctl subscribe thread died: {e}")


def main():
    emit_state()
    threading.Thread(target=listen_pactl, daemon=True).start()
    threading.Thread(target=listen_mpris, daemon=True).start()

    # Explicit readline loop instead of `for line in sys.stdin:` - iterating
    # stdin directly can raise if the pipe gets closed out from under us (e.g.
    # Quickshell tearing the Process down), and that exception happens outside
    # any try/except here, which used to kill main() - and the whole process,
    # since listen_pactl/listen_mpris are daemon threads with nothing left to
    # keep them alive. That silent death is what "nothing displays" was.
    while True:
        try:
            line = sys.stdin.readline()
        except Exception as e:
            log_error(f"stdin read failed, exiting: {e}")
            break

        if not line:
            # EOF - stdin closed. Exit the loop cleanly rather than looping
            # forever on empty reads or letting iteration protocol raise.
            break

        line = line.strip()
        if not line:
            continue

        try:
            cmd = json.loads(line)
            action = cmd.get("action")
            if action == "volume":
                subprocess.run(["pactl", f"set-{cmd['type']}-volume", str(cmd['id']), str(cmd['value'])])
            elif action == "mute":
                subprocess.run(["pactl", f"set-{cmd['type']}-mute", str(cmd['id']), str(cmd['value'])])
            elif action == "default":
                subprocess.run(["pactl", f"set-default-{cmd['type']}", cmd['name']])
            elif action == "port":
                subprocess.run(["pactl", f"set-{cmd['type']}-port", str(cmd['id']), cmd['port']])
            elif action == "profile":
                subprocess.run(["pactl", "set-card-profile", str(cmd['card']), cmd['profile']])
            elif action == "mpris":
                # Route to the player actually shown in the UI, not playerctl's
                # own idea of the "default" player.
                p_flag = ["-p", _last_target_player] if _last_target_player else []
                if cmd.get("cmd") == "position":
                    subprocess.run(["playerctl"] + p_flag + ["position", str(cmd.get("value"))])
                else:
                    subprocess.run(["playerctl"] + p_flag + [cmd.get("cmd")])
            emit_state()
        except Exception as e:
            log_error(f"Error handling cmd {line}: {e}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Last-resort net so a truly unexpected exception at least gets logged
        # instead of vanishing into a silently-dead process.
        log_error(f"Fatal error, backend exiting: {e}")
