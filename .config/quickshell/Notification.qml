import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  nText.implicitWidth + 4
    implicitHeight: 26
    property bool _has: false
    property bool _dnd: false
    property int  _count: 0

    Process {
        id: swayncProc
        command: ["swaync-client", "-swb"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var v = line.trim()
                if (!v) return
                try {
                    var d = JSON.parse(v)
                    // swaync outputs: {"count":N,"dnd":bool,"cc-open":bool,"inhibited":bool}
                    root._count = d.count   || 0
                    root._has   = root._count > 0
                    root._dnd   = d.dnd     || false
                } catch(e) {
                    // Sometimes outputs plain text — ignore
                }
            }
        }
    }

    Text {
        id: nText
        anchors.centerIn: parent
        rightPadding: 6
        text: {
            if (root._dnd)  return "\uDB82\uDE91"   // U+F0A91 — dnd on
            if (root._has)  return "\uDB80\uDD78"   // U+F0178 — has notifications
            return           "\uDB80\uDC9C"         // U+F009C — clear
        }
        font.family:    "JetBrains Mono Nerd Font"
        font.pixelSize: 15
        color: {
            if (root._dnd) return theme.color4  || "#89b4fa"
            if (root._has) return theme.caution || "#fab387"
            return          theme.color1        || "#cba6f7"
        }
        verticalAlignment: Text.AlignVCenter
    }

    Process { id: notifToggle; running: false; command: ["swaync-client", "-t", "-sw"] }
    Process { id: notifDnd;    running: false; command: ["swaync-client", "-d", "-sw"] }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) { notifToggle.running = false; notifToggle.running = true }
            else                                { notifDnd.running    = false; notifDnd.running    = true }
        }
    }

    HoverHandler {
        onHoveredChanged: tooltipBridge.show(root, hovered, [
            root._dnd ? "Do not disturb" :
            root._has ? root._count + " notification" + (root._count === 1 ? "" : "s") :
                        "No notifications"
        ])
    }
}
