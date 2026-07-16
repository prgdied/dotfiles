import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth:  200
    implicitHeight: 26
	property string _bars: ""

	signal toggleMediaCenter()

    Timer {
        interval: 800; running: true; repeat: false
        onTriggered: cavaProc.running = true
    }

    Timer {
        id: restartTimer
        interval: 3000; running: false; repeat: false
        onTriggered: cavaProc.running = true
    }

    Process {
        id: cavaProc
        command: ["bash", "-c",
            "export HOME=/home/payton; " +
            "export PATH=/usr/bin:/usr/local/bin:/bin:$PATH; " +
            "printf '[general]\\nbars = 12\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 7\\n' > /tmp/qs_cava_config; " +
            "cava -p /tmp/qs_cava_config | while IFS= read -r line; do " +
            "echo \"$line\" | sed 's/;//g;s/0/\\xe2\\x96\\x81/g;s/1/\\xe2\\x96\\x82/g;s/2/\\xe2\\x96\\x83/g;s/3/\\xe2\\x96\\x84/g;s/4/\\xe2\\x96\\x85/g;s/5/\\xe2\\x96\\x86/g;s/6/\\xe2\\x96\\x87/g;s/7/\\xe2\\x96\\x88/g'; " +
            "done"]
        running: false
        onRunningChanged: {
            if (!running) { root._bars = ""; restartTimer.running = true }
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var t = line.replace(/\s+$/, '')
                if (t) root._bars = t
            }
        }
    }

    Text {
        z: 1
        anchors.centerIn: parent
        text:             root._bars || ""
        font.family:      "JetBrains Mono Nerd Font"
        font.pixelSize:   18
        color:            theme.color1 || "#cba6f7"
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        z: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton)
                root.toggleMediaCenter()
            else if (mouse.button === Qt.RightButton)
                Qt.createQmlObject('import Quickshell.Io; Process{command:["pactl","set-source-mute","@DEFAULT_SOURCE@","toggle"];running:true}', root)
            else if (mouse.button === Qt.MiddleButton)
                Qt.createQmlObject('import Quickshell.Io; Process{command:["foot","cava"];running:true}', root)
        }
        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0)
                Qt.createQmlObject('import Quickshell.Io; Process{command:["playerctl","next"];running:true}', root)
            else
                Qt.createQmlObject('import Quickshell.Io; Process{command:["playerctl","previous"];running:true}', root)
        }
    }
}
