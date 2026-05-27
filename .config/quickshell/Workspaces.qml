import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitHeight: 26
    implicitWidth:  wsRow.implicitWidth

    property string targetOutput: ""

    property var sortedWorkspaces: {
        var allWs = niriIpc.workspaces
        if (!allWs || allWs.length === 0) return []
        // If targetOutput is empty or no workspaces match, show all workspaces
        // This handles single-monitor setups where output name might differ
        var filtered = allWs.filter(function(w) {
            return !root.targetOutput || w.output === root.targetOutput
        })
        if (filtered.length === 0) filtered = allWs
        filtered.sort(function(a, b) {
            return (a.idx || a.id) - (b.idx || b.id)
        })
        return filtered
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.sortedWorkspaces

            Item {
                id: wsBtn
                property var  wsData:    modelData
                property bool isFocused: modelData.is_focused
                property bool isHovered: false

                implicitWidth:  wsLabel.implicitWidth + 10
                implicitHeight: 26

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    height: (wsBtn.isFocused || wsBtn.isHovered) ? 2 : 0
                    color:  wsBtn.isFocused ? (theme.caution || "#fab387") : (theme.color15 || "#a6e3a1")
                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }
                }

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    text:           String(modelData.idx !== undefined ? modelData.idx : modelData.id)
                    font.family:    theme.fontMain    || "Monocraft"
                    font.pointSize: theme.fontSize    || 11
                    font.bold:      true
                    color: wsBtn.isFocused  ? (theme.color5  || "#f38ba8") :
                           wsBtn.isHovered  ? (theme.color15 || "#a6e3a1") :
                                              (theme.color1  || "#cba6f7")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Process {
                    id: wsFocusProc
                    running: false
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered:  wsBtn.isHovered = true
                    onExited:   wsBtn.isHovered = false
                    onClicked: {
                        wsFocusProc.command = ["niri", "msg", "action",
                            "focus-workspace", String(wsBtn.wsData.idx || wsBtn.wsData.id)]
                        wsFocusProc.running = false
                        wsFocusProc.running = true
                    }
                }
            }
        }
    }
}
