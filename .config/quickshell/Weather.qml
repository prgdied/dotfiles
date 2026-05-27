import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  wText.implicitWidth + 6
    implicitHeight: 26
    property string _val:     "?°"
    property string _tooltip: ""

    Timer {
        interval: 1800000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { weatherProc.running = false; weatherProc.running = true }
    }

    Process {
        id: weatherProc
        command: ["bash", "-c",
            "wttrbar --nerd --fahrenheit --location 47403 2>/dev/null | " +
            "python3 -c \"" +
                "import sys,json;" +
                "d=json.load(sys.stdin);" +
                "print(d.get('text','?'));" +
                "print(d.get('tooltip',''))\""]
        stdout: SplitParser {
            splitMarker: "\n"
            property int    _line:   0
            property string _tipBuf: ""
            onRead: function(line) {
                if (_line === 0) {
                    if (line.trim()) root._val = line.trim() + "\u00B0"
                } else {
                    // Preserve blank lines as empty string entries for spacing
                    _tipBuf += (_tipBuf ? "\n" : "") + line
                }
                _line++
            }
        }
        onRunningChanged: {
            if (!running) {
                root._tooltip = weatherProc.stdout._tipBuf
                weatherProc.stdout._line   = 0
                weatherProc.stdout._tipBuf = ""
            }
        }
    }

    Text {
        id: wText
        anchors.centerIn: parent
        rightPadding: 3
        text:           root._val
        font.family:    "Monocraft"
        font.pointSize: 11
        font.bold:      true
        color:          theme.color1 || "#cba6f7"
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && root._tooltip) {
                // Split preserving blank lines — blank lines become a single space
                // so they render as visible gaps between day sections
                var lines = root._tooltip.split("\n").map(function(l) {
                    return l === "" ? " " : l
                })
                tooltipBridge.show(root, true, lines)
            } else {
                tooltipBridge.show(root, false, [])
            }
        }
    }

    Process { id: astroProc; running: false; command: ["bash", "/home/payton/Scripts/Astroterm.sh"] }
    MouseArea {
        anchors.fill: parent
        onClicked: { astroProc.running = false; astroProc.running = true }
    }
}
