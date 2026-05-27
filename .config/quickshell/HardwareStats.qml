import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  statsRow.implicitWidth
    implicitHeight: 26

    property int cpuPct:        0
    property int ramPct:        0
    property int tempC:         0
    property int gpuPct:        0
    property int ramUsedMb:     0
    property int ramTotalMb:    0
    property string gpuTipText: ""

    property bool cpuCrit:  cpuPct  >= 90
    property bool ramCrit:  ramPct  >= 90
    property bool tempCrit: tempC   >= 90

    property bool _blinkState: false
    Timer {
        interval: 67; running: root.cpuCrit || root.ramCrit || root.tempCrit; repeat: true
        onTriggered: root._blinkState = !root._blinkState
    }
    function _c(isCrit) { return (isCrit && root._blinkState) ? theme.caution : theme.color4 }

    Timer {
        interval: 4000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running  = false; cpuProc.running  = true
            ramProc.running  = false; ramProc.running  = true
            tempProc.running = false; tempProc.running = true
            gpuProc.running  = false; gpuProc.running  = true
        }
    }

    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | awk '/^%Cpu/{print int($2+$4)}'"]
        stdout: SplitParser { splitMarker: "\n"
            onRead: function(l) { if(l.trim()) root.cpuPct = parseInt(l)||0 } }
    }
    Process {
        id: ramProc
        command: ["bash", "-c", "free -m | awk '/^Mem/{printf \"%d\\n%d\\n%d\\n\", $3/$2*100, $3, $2}'"]
        stdout: SplitParser {
            splitMarker: "\n"; property int _line: 0
            onRead: function(l) {
                if (!l.trim()) return
                if (_line===0) root.ramPct     = parseInt(l)||0
                if (_line===1) root.ramUsedMb  = parseInt(l)||0
                if (_line===2) root.ramTotalMb = parseInt(l)||0
                _line++
            }
        }
        onRunningChanged: if (!running) ramProc.stdout._line = 0
    }
    Process {
        id: tempProc
        command: ["bash", "-c",
            "(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null || " +
            "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null) | awk '{print int($1/1000)}'"]
        stdout: SplitParser { splitMarker: "\n"
            onRead: function(l) { if(l.trim()) root.tempC = parseInt(l)||0 } }
    }
    Process {
        id: gpuProc
        command: ["gpu-usage-waybar"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(l) {
                if (!l.trim()) return
                try {
                    var d = JSON.parse(l)
                    root.gpuPct     = parseInt((d.text||"0").replace("%","").trim()) || 0
                    root.gpuTipText = d.tooltip || ""
                } catch(e) {}
            }
        }
    }

    Row {
        id: statsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Temp
        Item {
            implicitWidth: tempRow.implicitWidth; implicitHeight: 26
            Row { id: tempRow; spacing: 4; leftPadding: 4; rightPadding: 4; anchors.verticalCenter: parent.verticalCenter
                Text { text: "\uF2C8"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 15; color: root._c(root.tempCrit); anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.tempC + "\u00B0"; font.family: "Monocraft"; font.pointSize: 11; font.bold: true; color: root._c(root.tempCrit); anchors.verticalCenter: parent.verticalCenter }
            }
            HoverHandler { onHoveredChanged: tooltipBridge.show(parent, hovered, [root.tempC + "\u00B0C  \u2014  " + Math.round(root.tempC*9/5+32) + "\u00B0F"]) }
        }

        // CPU
        Item {
            implicitWidth: cpuRow.implicitWidth; implicitHeight: 26
            Row { id: cpuRow; spacing: 4; leftPadding: 4; rightPadding: 4; anchors.verticalCenter: parent.verticalCenter
                Text { text: "\uF4BC"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 15; color: root._c(root.cpuCrit); anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.cpuPct + "%"; font.family: "Monocraft"; font.pointSize: 11; font.bold: true; color: root._c(root.cpuCrit); anchors.verticalCenter: parent.verticalCenter }
            }
            HoverHandler { onHoveredChanged: tooltipBridge.show(parent, hovered, ["CPU: " + root.cpuPct + "%"]) }
            MouseArea { anchors.fill: parent; onClicked: Qt.createQmlObject('import Quickshell.Io; Process{command:["kitty","bash","-ic","btop"];running:true}', root) }
        }

        // RAM
        Item {
            implicitWidth: ramRow.implicitWidth; implicitHeight: 26
            Row { id: ramRow; spacing: 4; leftPadding: 4; rightPadding: 4; anchors.verticalCenter: parent.verticalCenter
                Text { text: "\uEFC5"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 15; color: root._c(root.ramCrit); anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.ramPct + "%"; font.family: "Monocraft"; font.pointSize: 11; font.bold: true; color: root._c(root.ramCrit); anchors.verticalCenter: parent.verticalCenter }
            }
            HoverHandler { onHoveredChanged: tooltipBridge.show(parent, hovered, [root.ramUsedMb + " / " + root.ramTotalMb + " MiB", root.ramPct + "% used"]) }
            MouseArea { anchors.fill: parent; onClicked: Qt.createQmlObject('import Quickshell.Io; Process{command:["kitty","bash","-ic","btop"];running:true}', root) }
        }

        // GPU
        Item {
            implicitWidth: gpuRow.implicitWidth; implicitHeight: 26
            Row { id: gpuRow; spacing: 4; leftPadding: 4; rightPadding: 4; anchors.verticalCenter: parent.verticalCenter
                Text { text: "\udb82\udcae"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 22; color: theme.color4; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.gpuPct + "%"; font.family: "Monocraft"; font.pointSize: 11; font.bold: true; color: theme.color4; anchors.verticalCenter: parent.verticalCenter }
            }
            HoverHandler { onHoveredChanged: tooltipBridge.show(parent, hovered,
                root.gpuTipText.split("\n").filter(function(l){ return l.trim() !== "" })) }
            MouseArea { anchors.fill: parent; onClicked: Qt.createQmlObject('import Quickshell.Io; Process{command:["steam"];running:true}', root) }
        }
    }
}
