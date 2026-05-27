import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  netText.implicitWidth
    implicitHeight: 26

    property bool   _online:   false
    property bool   _wifi:     false
    property int    _strength: 0
    property string _ssid:     ""

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = false; netProc.running = true }
    }

    Process {
        id: wifiToggleProc
        // Wrapping in bash -c ensures your GUI environment variables are inherited
        command: ["bash", "-c", "wifi-manager --toggle"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            wifiToggleProc.running = false 
            wifiToggleProc.running = true  
        }
    }

    Process {
        id: netProc
        command: ["bash", "-c",
            "nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; print $3; exit}'; " +
            "ip route show default 2>/dev/null | grep -c . || echo 0"]
        stdout: SplitParser {
            splitMarker: "\n"
            property int _line: 0
            onRead: function(line) {
                var v = line.trim()
                if (_line === 0) {
                    root._wifi     = v !== "" && !isNaN(parseInt(v))
                    root._strength = parseInt(v) || 0
                    if (root._wifi) root._online = true
                }
                if (_line === 1 && root._wifi)  root._ssid   = v
                if (_line === 1 && !root._wifi) root._online = parseInt(v) > 0
                if (_line === 2 && !root._wifi) root._online = parseInt(v) > 0
                _line++
            }
        }
        onRunningChanged: if (!running) netProc.stdout._line = 0
    }

    property string _wifiIcon: {
        var s = _strength
        if (s < 20) return "\uDB82\uDD19"
        if (s < 40) return "\uDB82\uDD1C"
        if (s < 60) return "\uDB82\uDD1F"
        if (s < 80) return "\uDB82\uDD22"
        return       "\uDB82\uDD2B"
    }

    Text {
        id: netText
        anchors.centerIn: parent
        leftPadding: 4; rightPadding: 4
        text: {
            if (!root._online) return "\uEAD0"          // unplugged/disconnected
            if (root._wifi)    return root._wifiIcon
            return "\uDB80\uDE00"                        // ethernet U+F0200
        }
        font.family:    "JetBrains Mono Nerd Font"
        font.pixelSize: 15
        color:          root._online ? theme.color4 : (theme.caution || "#fab387")
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler {
        onHoveredChanged: tooltipBridge.show(root, hovered,
            !root._online ? ["Disconnected"] :
            root._wifi    ? [root._ssid || "WiFi", "Signal: " + root._strength + "%"] :
                            ["Ethernet"])
    }
}
