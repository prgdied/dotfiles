import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: popup
    required property var targetScreen
    property var barWindow // kept so shell.qml's existing `barWindow: bar` binding still works; unused now
    required property bool isOpen
    signal requestClose()

    screen: targetScreen

    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    implicitHeight: panelHeight

    WlrLayershell.layer:          WlrLayer.Overlay
    WlrLayershell.keyboardFocus:  WlrKeyboardFocus.None
    WlrLayershell.namespace:      "quickshell-media-center"
    WlrLayershell.exclusionMode:  ExclusionMode.Ignore
    WlrLayershell.margins.bottom: 26 // matches the bar's implicitHeight - same trick PowerMenu uses to sit flush

    color:   "transparent"
    visible: popup.isOpen || closingTimer.running

    // ── Layout constants ──────────────────────────────────────────────────────
    readonly property int panelWidth:  800
    readonly property int panelHeight: 520

    // ── Slide animation (matches PowerMenu) ──────────────────────────────────
    property real slideY: panelHeight
    Timer { id: closingTimer; interval: 230; repeat: false }

    onIsOpenChanged: {
        if (isOpen) {
            slideY = panelHeight
            openAnim.start()
        } else {
            closingTimer.restart()
            closeAnim.start()
        }
    }

    NumberAnimation {
        id: openAnim; target: popup; property: "slideY"
        from: panelHeight; to: 0; duration: 220; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: closeAnim; target: popup; property: "slideY"
        from: 0; to: panelHeight; duration: 200; easing.type: Easing.InCubic
    }

    // ── Click outside to close ────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: popup.isOpen
        onClicked: popup.requestClose()
    }

    // Pywal-derived surface tints instead of hardcoded Catppuccin hex, so internal
    // panels/rows/tracks follow whatever theme.background/theme.foreground pywal
    // currently has, instead of staying a fixed dark-blue no matter what.
    readonly property color surface1: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.06)
    readonly property color surface2: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)

    property var mprisData: ({ "title": "No Media Playing", "artist": "Unknown Artist", "album": "", "art": "", "status": "Stopped", "position": 0.0, "length": 0.0 })
    property var audioData: ({ "sinks": [], "sources": [], "playback": [], "recording": [], "cards": [] })
    property int activeTab: 0
    property real localPos: 0.0
    property string lastTrackTitle: ""

    Timer {
        interval: 1000
        running: mprisData.status === "Playing" && isOpen && !mprisSlider.isDragging
        repeat: true
        onTriggered: {
            if (localPos < mprisData.length) localPos += 1.0
        }
    }

    onMprisDataChanged: {
        if (mprisSlider.isDragging) return
        if (mprisData.title !== lastTrackTitle) {
            // Track (or active player) changed - snap immediately
            localPos = mprisData.position
            lastTrackTitle = mprisData.title
        } else if (Math.abs(mprisData.position - localPos) > 2.0) {
            // Only resync on a real desync (external seek, pause drift), not on
            // every minor backend snapshot - resyncing on every update was what
            // made the slider visibly jitter back and forth while playing.
            localPos = mprisData.position
        }
    }

    Process {
        id: backend
        command: ["python3", "-u", "/home/payton/scripts/quickshell/audio-backend.py"]
        running: popup.isOpen
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                try {
                    var data = JSON.parse(line)
                    if (data.mpris) popup.mprisData = data.mpris
                    if (data.audio) popup.audioData = data.audio
                } catch(e) {}
            }
        }
        function sendCommand(cmd) {
            write(JSON.stringify(cmd) + "\n")
        }
    }

    function formatTime(secs) {
        if (isNaN(secs) || secs < 0) return "0:00"
        var m = Math.floor(secs / 60)
        var s = Math.floor(secs % 60)
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    component AudioSlider: Item {
        id: sld
        property real value: 0.0
        property real maxVal: 1.0
        property bool isDragging: false
        // Local value driven directly by the mouse while dragging, so the handle
        // tracks the cursor immediately instead of waiting on a backend round-trip
        // (pactl/playerctl call -> emitted state -> value binding update) each frame.
        property real dragValue: 0.0
        readonly property real displayValue: isDragging ? dragValue : value
        // Last value actually sent to the backend. Only emit moved() again once
        // the rounded value changes, instead of on every single mouse-move pixel -
        // otherwise a drag floods the backend with a subprocess call + full state
        // rescan per pixel, and the resulting command backlog is what was still
        // making dragging feel laggy/buggy.
        property real lastEmitted: -1
        signal moved(real val)
        implicitHeight: 24
        implicitWidth: parent.width

        Rectangle {
            id: sldTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: popup.surface2

            Rectangle {
                height: parent.height
                radius: 3
                width: parent.width * Math.min(sld.displayValue / sld.maxVal, 1.0)
                color: theme.color4 || "#89b4fa"
            }

            Rectangle {
                x: (sldTrack.width * Math.min(sld.displayValue / sld.maxVal, 1.0)) - (width / 2)
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 3
                color: theme.foreground || "#cdd6f4"
                border.color: theme.color1 || "#cba6f7"
                border.width: 1
            }
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: { sld.isDragging = true; handlePosition(mouse) }
            onPositionChanged: { if (sld.isDragging) handlePosition(mouse) }
            onReleased: { sld.isDragging = false }
            function handlePosition(mouse) {
                var pct = Math.max(0, Math.min(mouse.x, width)) / width
                var val = pct * sld.maxVal
                sld.dragValue = val
                if (Math.round(val) !== Math.round(sld.lastEmitted)) {
                    sld.lastEmitted = val
                    sld.moved(val)
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        width: parent.width
        height: devCol.implicitHeight + 16
        color: popup.surface1
        border.color: modelData.is_default ? theme.color1 : "transparent"
        border.width: 1
        radius: 3

        property string devType: ""

        Column {
            id: devCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text { text: devType === "sink" ? "\uf028" : "\uf130"; font.family: theme.fontMono; font.pixelSize: 14; color: theme.color1 }
                    Text { text: modelData.description; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; elide: Text.ElideRight; width: 380 }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        width: 30; height: 30; radius: 3
                        color: modelData.is_default ? theme.color15 : popup.surface2
                        Text { anchors.centerIn: parent; text: "\uf00c"; font.family: theme.fontMono; font.pixelSize: 14; color: modelData.is_default ? theme.background : theme.foreground }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.sendCommand({action: "default", type: devType, name: modelData.name}) }
                    }
                    // Unmuted state is now the one that "pops" (color5) - muted is
                    // the quiet/de-emphasized state, which reads more naturally.
                    Rectangle {
                        width: 30; height: 30; radius: 3
                        color: modelData.mute ? popup.surface2 : theme.color5
                        Text { anchors.centerIn: parent; text: "\uf028"; font.family: theme.fontMono; font.pixelSize: 14; color: modelData.mute ? theme.color1 : theme.background }
                        // Drawn manually rather than relying on a specific mute/slash
                        // glyph existing in whatever Nerd Font variant is installed -
                        // a missing glyph renders as an empty box (tofu).
                        Rectangle {
                            visible: modelData.mute
                            anchors.centerIn: parent
                            width: 20; height: 2; radius: 1
                            rotation: 45
                            color: theme.color1
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.sendCommand({action: "mute", type: devType, id: modelData.id, value: "toggle"}) }
                    }
                }
            }

            AudioSlider {
                value: modelData.volume
                maxVal: 150
                onMoved: function(val) {
                    backend.sendCommand({action: "volume", type: devType, id: modelData.id, value: Math.round(val) + "%"})
                }
            }

            Item {
                width: parent.width
                height: 16
                Text { text: "0%"; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; opacity: 0.55; anchors.left: parent.left }
                Text { text: modelData.volume + "% (" + modelData.db + ")"; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; opacity: 0.55; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "150%"; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; opacity: 0.55; anchors.right: parent.right }
            }
        }
    }

    component StreamRow: Rectangle {
        width: parent.width
        height: streamCol.implicitHeight + 16
        color: popup.surface1
        radius: 3
        property string streamType: ""

        Column {
            id: streamCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text { text: streamType === "sink-input" ? "\uf001" : "\uf130"; font.family: theme.fontMono; font.pixelSize: 14; color: theme.color1 }
                    Text { text: modelData.name; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; elide: Text.ElideRight; width: 420 }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        width: 30; height: 30; radius: 3
                        color: modelData.mute ? popup.surface2 : theme.color5
                        Text { anchors.centerIn: parent; text: "\uf028"; font.family: theme.fontMono; font.pixelSize: 14; color: modelData.mute ? theme.color1 : theme.background }
                        Rectangle {
                            visible: modelData.mute
                            anchors.centerIn: parent
                            width: 20; height: 2; radius: 1
                            rotation: 45
                            color: theme.color1
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.sendCommand({action: "mute", type: streamType, id: modelData.id, value: "toggle"}) }
                    }
                }
            }

            AudioSlider {
                value: modelData.volume
                maxVal: 150
                onMoved: function(val) {
                    backend.sendCommand({action: "volume", type: streamType, id: modelData.id, value: Math.round(val) + "%"})
                }
            }

            Item {
                width: parent.width
                height: 16
                Text { text: "0%"; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; opacity: 0.55; anchors.left: parent.left }
                Text { text: modelData.volume + "% (" + modelData.db + ")"; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; opacity: 0.55; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "150%"; font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; opacity: 0.55; anchors.right: parent.right }
            }
        }
    }

    Rectangle {
        id: panelSurface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: popup.panelWidth
        height: popup.panelHeight
        transform: Translate { y: popup.slideY }
        color: theme.background || "#1e1e2e"
        border.color: theme.color1 || "#cba6f7"
        border.width: 1
        radius: 3
        clip: true

        // Eats clicks so they don't fall through to the close-catcher MouseArea behind it
        MouseArea { anchors.fill: parent }

        Column {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["Playback", "Recording", "Outputs", "Inputs", "Cards"]
                    Rectangle {
                        width: (parent.width - 24) / 5
                        height: 36
                        radius: 3
                        color: activeTab === index ? theme.color4 : popup.surface1
                        border.color: activeTab === index ? "transparent" : theme.color1
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.family: theme.fontMain
                            font.pixelSize: 15
                            font.weight: activeTab === index ? Font.Bold : Font.Normal
                            color: activeTab === index ? theme.background : theme.foreground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activeTab = index
                        }
                    }
                }
            }

            Flickable {
                width: parent.width
                height: mainCol.height - 48 - (mprisContainer.visible ? 162 : 0)
                contentHeight: listCol.implicitHeight
                clip: true

                Column {
                    id: listCol
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: activeTab === 0 ? popup.audioData.playback : []
                        StreamRow { streamType: "sink-input" }
                    }

                    Repeater {
                        model: activeTab === 1 ? popup.audioData.recording : []
                        StreamRow { streamType: "source-output" }
                    }

                    Repeater {
                        model: activeTab === 2 ? popup.audioData.sinks : []
                        DeviceRow { devType: "sink" }
                    }

                    Repeater {
                        model: activeTab === 3 ? popup.audioData.sources : []
                        DeviceRow { devType: "source" }
                    }

                    Repeater {
                        model: activeTab === 4 ? popup.audioData.cards : []
                        Rectangle {
                            id: cardRow
                            width: parent.width
                            height: cardCol.implicitHeight + 16
                            color: popup.surface1
                            radius: 3
                            property var card: modelData

                            Column {
                                id: cardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: cardRow.card.description
                                    font.family: theme.fontMain
                                    font.pixelSize: 11
                                    color: theme.foreground
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 6

                                    Repeater {
                                        model: cardRow.card.profiles
                                        Rectangle {
                                            id: profileChip
                                            readonly property bool active: cardRow.card.active_profile === modelData.name
                                            width: chipText.implicitWidth + 16
                                            height: 26
                                            radius: 3
                                            color: active ? theme.color4 : popup.surface2

                                            Text {
                                                id: chipText
                                                anchors.centerIn: parent
                                                text: modelData.description
                                                font.family: theme.fontMain
                                                font.pixelSize: 9
                                                color: profileChip.active ? theme.background : theme.foreground
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: backend.sendCommand({action: "profile", card: cardRow.card.name, profile: modelData.name})
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: (activeTab === 0 && popup.audioData.playback.length === 0) || (activeTab === 1 && popup.audioData.recording.length === 0)
                        text: activeTab === 0 ? "No applications currently playing audio" : "No applications currently recording audio"
                        font.family: theme.fontMain
                        font.pixelSize: 12
                        color: theme.foreground
                        opacity: 0.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 100
                    }
                }
            }

            Rectangle {
                id: mprisContainer
                width: parent.width
                height: 150
                color: popup.surface1
                radius: 3
                border.color: theme.color1
                border.width: 1
                visible: popup.mprisData.status !== "Stopped" && popup.mprisData.title !== "No Media" && popup.mprisData.title !== "No Media Playing"

                Item {
                    id: art
                    width: 90
                    height: 90
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: vinylDisc
                        anchors.fill: parent
                        radius: width / 2
                        color: popup.surface2

                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: popup.mprisData.art || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        // Rectangle.clip only clips children to the bounding box, not to
                        // the rounded radius - so a plain `clip: true` here still let the
                        // square Image paint right over the rounded corners. Mask it
                        // properly instead.
                        MultiEffect {
                            anchors.fill: artImg
                            source: artImg
                            maskEnabled: true
                            maskSource: vinylMask
                            visible: artImg.status === Image.Ready
                        }

                        Rectangle {
                            id: vinylMask
                            anchors.fill: parent
                            radius: width / 2
                            color: "white"
                            opacity: 0
                            layer.enabled: true
                        }

                        Text { anchors.centerIn: parent; text: "\uf001"; font.family: theme.fontMono; font.pixelSize: 24; color: theme.color1; visible: artImg.status !== Image.Ready }

                        // Spindle hole, like a vinyl record's center
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.16
                            height: width
                            radius: width / 2
                            color: theme.background || "#1e1e2e"
                            border.color: theme.color1 || "#cba6f7"
                            border.width: 1
                        }
                    }

                    RotationAnimation {
                        target: vinylDisc
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 1800 // 33 1/3 RPM - standard LP turntable speed
                        loops: Animation.Infinite
                        running: popup.mprisData.status === "Playing"
                    }
                }

                // Left/right margins mirror art.width so this column's true center
                // lines up with mprisContainer's true center, instead of being
                // centered only within the leftover space next to the art.
                Column {
                    id: infoCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: art.width + 26
                    anchors.rightMargin: art.width + 26
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 6
                    spacing: 8

                    Column {
                        width: parent.width
                        spacing: 3
                        Text {
                            text: popup.mprisData.title
                            font.family: theme.fontMain
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: theme.foreground
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: popup.mprisData.artist + (popup.mprisData.album ? "  |  " + popup.mprisData.album : "")
                            font.family: theme.fontMain
                            font.pixelSize: 12
                            color: theme.foreground
                            opacity: 0.6
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 3
                        AudioSlider {
                            id: mprisSlider
                            value: popup.localPos
                            maxVal: popup.mprisData.length
                            onMoved: function(val) {
                                backend.sendCommand({action: "mpris", cmd: "position", value: val})
                            }
                        }
                        Item {
                            width: parent.width
                            height: 14
                            Text { text: popup.formatTime(popup.localPos); font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; anchors.left: parent.left }
                            Text { text: popup.formatTime(popup.mprisData.length); font.family: theme.fontMain; font.pixelSize: 11; color: theme.foreground; anchors.right: parent.right }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 28
                        Item {
                            width: 32; height: 32
                            Text { anchors.centerIn: parent; text: "\uf048"; font.family: theme.fontMono; font.pixelSize: 16; color: theme.color1 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.sendCommand({action: "mpris", cmd: "previous"}) }
                        }
                        Item {
                            width: 32; height: 32
                            Text { anchors.centerIn: parent; text: popup.mprisData.status === "Playing" ? "\uf04c" : "\uf04b"; font.family: theme.fontMono; font.pixelSize: 16; color: theme.color1 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.sendCommand({action: "mpris", cmd: "play-pause"}) }
                        }
                        Item {
                            width: 32; height: 32
                            Text { anchors.centerIn: parent; text: "\uf051"; font.family: theme.fontMono; font.pixelSize: 16; color: theme.color1 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.sendCommand({action: "mpris", cmd: "next"}) }
                        }
                    }
                }
            }
        }
    }
}
