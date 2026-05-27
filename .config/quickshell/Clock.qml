import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  clockRow.implicitWidth + 8
    implicitHeight: 26

    function getWeek() {
        var d = new Date()
        var onejan = new Date(d.getFullYear(), 0, 1)
        return Math.ceil((((d - onejan) / 86400000) + onejan.getDay() + 1) / 7)
    }

    property string _date: "00"
    property string _time: "0:00"

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var n = new Date()
            root._date = n.getDate().toString().padStart(2, "0")
            var h = n.getHours() % 12 || 12
            var m = n.getMinutes().toString().padStart(2, "0")
            root._time = h + ":" + m
        }
    }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 5

        // Calendar icon U+F073
        Text {
            text: "\uF073"
            font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 15
            color: theme.color1 || "#cba6f7"
            anchors.verticalCenter: parent.verticalCenter
        }
        // Date
        Text {
            text: root._date
            font.family: "Monocraft"; font.pointSize: 11; font.bold: true
            color: theme.color1 || "#cba6f7"
            anchors.verticalCenter: parent.verticalCenter
        }
        // Clock icon U+F017
        Text {
            text: "\uF017"
            font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 15
            color: theme.color1 || "#cba6f7"
            anchors.verticalCenter: parent.verticalCenter
        }
        // Time
        Text {
            text: root._time
            font.family: "Monocraft"; font.pointSize: 11; font.bold: true
            color: theme.color1 || "#cba6f7"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        onHoveredChanged: tooltipBridge.show(root, hovered, [
            Qt.formatDate(new Date(), "dddd"),
            Qt.formatDate(new Date(), "MMMM d, yyyy"),
            "Week " + root.getWeek()
        ])
    }

    Process {
        id: calProc; running: false
        command: ["bash", "-c", "chromium --app=https://calendar.google.com &"]
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { calProc.running = false; calProc.running = true }
    }
}
