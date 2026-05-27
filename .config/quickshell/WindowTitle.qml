import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  titleRow.implicitWidth + 8
    implicitHeight: 26

    property int maxChars: 30

    // Look up XDG icon path from app_id
    property string _iconPath: ""

    Process {
        id: iconLookup
        property string _appId: ""
        command: ["bash", "-c",
            "find /usr/share/icons /usr/share/pixmaps ~/.local/share/icons 2>/dev/null " +
            "-name '" + iconLookup._appId + ".*' -o " +
            "-name '" + iconLookup._appId.toLowerCase() + ".*' 2>/dev/null | " +
            "grep -E '\\.(png|svg)$' | head -1"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (line.trim()) root._iconPath = line.trim()
            }
        }
    }

    // Re-lookup icon when app changes
    onVisibleChanged: if (visible) _lookupIcon()
    Connections {
        target: niriIpc
        function onFocusedAppIdChanged() { root._lookupIcon() }
    }

    function _lookupIcon() {
        var id = niriIpc.focusedAppId
        if (!id) { root._iconPath = ""; return }
        iconLookup._appId = id
        iconLookup.running = false
        iconLookup.running = true
    }

    Row {
        id: titleRow
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 4
        spacing: 6

        // App icon — only show if we found one
        Image {
            visible: root._iconPath !== ""
            source:  root._iconPath !== "" ? ("file://" + root._iconPath) : ""
            width:   16
            height:  16
            anchors.verticalCenter: parent.verticalCenter
            smooth: true
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                var t = niriIpc.focusedWindowTitle
                if (!t) return ""
                return t.length > maxChars ? t.substring(0, maxChars - 1) + "\u2026" : t
            }
            font.family:    "Monocraft"
            font.pointSize: 11
            font.bold:      true
            color:          theme.color5 || "#f38ba8"
        }
    }
}
