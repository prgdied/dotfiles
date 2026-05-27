import QtQuick
import Quickshell.Io

Item {
    id: root

    property var    workspaces:         []
    property string focusedWindowTitle: ""
    property string focusedAppId:       ""
    property string focusedOutputName:  ""  // e.g. "DP-1", "HDMI-A-1"

    Timer {
        interval: 200; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { wsPoll.running = false; wsPoll.running = true }
    }

    Process {
        id: wsPoll
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                try { root.workspaces = JSON.parse(data) } catch(e) {}
            }
        }
    }

    Timer {
        interval: 300; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { winPoll.running = false; winPoll.running = true }
    }

    Process {
        id: winPoll
        command: ["bash", "-c",
            "niri msg -j focused-window 2>/dev/null | " +
            "python3 -c \"" +
                "import sys,json;" +
                "d=json.load(sys.stdin);" +
                "print(d.get('title','') if d else '');" +
                "print(d.get('app_id','') if d else '')" +
            "\" 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            property int _line: 0
            onRead: function(line) {
                var v = line.replace(/\s+$/, '')
                if (_line === 0) root.focusedWindowTitle = v
                if (_line === 1) root.focusedAppId       = v
                _line++
            }
        }
        onRunningChanged: if (!running) winPoll.stdout._line = 0
    }

    // Poll focused output name for wallpaper picker screen targeting
    Timer {
        interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { outputPoll.running = false; outputPoll.running = true }
    }

    Process {
        id: outputPoll
        command: ["bash", "-c",
            "niri msg -j focused-output 2>/dev/null | " +
            "python3 -c \"" +
                "import sys,json;" +
                "d=json.load(sys.stdin);" +
                "print(d.get('name','') if d else '')" +
            "\" 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                var v = data.replace(/\s+$/, '')
                if (v.length > 0) root.focusedOutputName = v
            }
        }
    }
}
