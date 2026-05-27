import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  hasBattery ? (ico.implicitWidth + 16) : 0
    implicitHeight: 26
    visible:        hasBattery

    property bool hasBattery: false

    Process {
        id: batDetect
        command: ["bash", "-c", "ls /sys/class/power_supply/BAT* 2>/dev/null | wc -l"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root.hasBattery = parseInt(line.trim()) > 0 }
        }
    }

    property int  pct:        100
    property bool charging:   false
    property string timeLeft: ""
    property bool isWarning:  pct <= 25 && !charging
    property bool isCritical: pct <= 10 && !charging

    property bool _blinkState: false
    Timer {
        interval: 67; running: root.isCritical && root.hasBattery; repeat: true
        onTriggered: root._blinkState = !root._blinkState
    }

    property color _iconColor: {
        if (isCritical) return root._blinkState ? theme.warning : theme.color4
        if (isWarning)  return theme.warning
        return theme.color4
    }

    readonly property var _icons: [
        "\udb80\udc8e","\udb80\udc7b","\udb80\udc7b","\udb80\udc7e","\udb80\udc7e",
        "\udb80\udc81","\udb80\udc81","\udb80\udc81","\udb80\udc79","\udb80\udc79","\udb80\udc79"
    ]
    property string _icon: {
        if (charging || pct >= 95) return "\udb80\udc84"
        return _icons[Math.min(Math.floor(pct / 10), 10)]
    }

    Timer {
        interval: 300; running: root.hasBattery; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = false; batProc.running = true }
    }

    Process {
        id: batProc
        command: ["bash", "-c",
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; " +
            // time remaining from upower
            "upower -i $(upower -e | grep BAT | head -1) 2>/dev/null | " +
            "awk '/time to/{printf $NF\" \"$(NF-1)}' || echo ''"]
        stdout: SplitParser {
            splitMarker: "\n"
            property int _line: 0
            onRead: function(line) {
                if (_line === 0) root.pct      = parseInt(line.trim()) || 100
                if (_line === 1) root.charging = line.trim() === "Charging" || line.trim() === "Full"
                if (_line === 2) root.timeLeft = line.trim()
                _line++
            }
        }
        onRunningChanged: if (!running) batProc.stdout._line = 0
    }

    Text {
        id: ico
        anchors.centerIn: parent
        text:  root._icon
        font.family:    "JetBrains Mono Nerd Font"
        font.pixelSize: 17
        color:          root._iconColor
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    HoverHandler {
        onHoveredChanged: {
            var lines = [
                root.pct + "% \u2014 " + (root.charging ? "Charging" :
                    root.pct >= 100 ? "Full" : "On battery")
            ]
            if (root.timeLeft) lines.push(root.timeLeft + " remaining")
            if (root.isWarning)  lines.push("Low battery")
            if (root.isCritical) lines.push("Critical!")
            tooltipBridge.show(root, hovered, lines)
        }
    }
}
