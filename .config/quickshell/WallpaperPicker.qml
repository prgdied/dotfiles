import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    screen: {
        var name = niriIpc.focusedOutputName
        if (name.length > 0) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === name)
                    return Quickshell.screens[i]
            }
        }
        return Quickshell.screens[0]
    }

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true
    implicitHeight: 220

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace:     "wallpaper-picker"

    color: "transparent"

    // ── Config ────────────────────────────────────────────────────────────────
    readonly property string wallDir:  "/home/payton/Pictures/Wallpapers"
    readonly property string thumbDir: "/home/payton/.cache/wallpaper-thumbs"
    readonly property string script:   "/home/payton/.config/rofi/scripts/select-wallpaper.sh"
    readonly property int    thumbW:   320
    readonly property int    borderPx: 4

    // ── Colors ────────────────────────────────────────────────────────────────
    property color bgColor:     "#1a1a1a"
    property color fgColor:     "#dadada"
    property color accentColor: "#cc7700"

    FileView {
        id: walColors
        path: "/home/payton/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(walColors.text())
                var c = d.colors
                var s = d.special
                if (s && s.background) root.bgColor     = s.background
                if (s && s.foreground) root.fgColor     = s.foreground
                if (c && c.color1)     root.accentColor = c.color1
            } catch(e) {}
        }
    }

    // ── State ─────────────────────────────────────────────────────────────────
    property var  wallpapers: []
    property bool deepMode:   false

    signal pickerClosed()

    function close() { slideOut.running = true }

    function thumbPath(wallPath) {
        return "file://" + thumbDir + "/" + Qt.md5(wallPath + "\n") + ".png"
    }

    function navigate(delta) {
        var count = listView.count
        if (count === 0) return
        listView.currentIndex = ((listView.currentIndex + delta) % count + count) % count
    }

    // ── Slide animation ───────────────────────────────────────────────────────
    property real slideOffset: implicitHeight

    NumberAnimation {
        id: slideIn
        target: root
        property: "slideOffset"
        from:     root.implicitHeight
        to:       0
        duration: 200
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOut
        target: root
        property: "slideOffset"
        from:     0
        to:       root.implicitHeight
        duration: 180
        easing.type: Easing.InCubic
        onFinished: root.pickerClosed()
    }

    Component.onCompleted: slideIn.running = true

    // ── Load wallpaper list ───────────────────────────────────────────────────
    Process {
        id: listProc
        property var _buf: []
        command: [
            "bash", "-c",
            "find '" + root.wallDir + "'" +
            (root.deepMode ? "" : " -maxdepth 1") +
            " -type f \\( -iname '*.jpg' -o -iname '*.jpeg'" +
            " -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\)" +
            " | sort"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var t = line.trim()
                if (t.length > 0) listProc._buf.push(t)
            }
        }
        onExited: {
            root.wallpapers = listProc._buf.slice()
            listProc._buf = []
            listView.forceActiveFocus()
        }
    }

    // ── Apply wallpaper ───────────────────────────────────────────────────────
    Process {
        id: applyProc
        property string pendingPath: ""
        command: ["bash", root.script, "apply-qs", pendingPath]
        running: false
        onExited: root.close()
    }

    function applyWallpaper(path) {
        applyProc.pendingPath = path
        applyProc.running = true
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        transform: Translate { y: root.slideOffset }
        color:        root.bgColor
        border.color: root.fgColor
        border.width: 2
        radius:       4
        clip:         true

        // Mousewheel scrolling — sits behind the listview delegates
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.navigate(-1)
                else if (event.angleDelta.y < 0)
                    root.navigate(1)
                event.accepted = true
            }
        }

        ListView {
            id: listView
            anchors.fill:    parent
            anchors.margins: 8
            orientation:     ListView.Horizontal
            spacing:         8
            clip:            true
            focus:           true
            model:           root.wallpapers

            highlightFollowsCurrentItem: true
            highlightMoveDuration:       150
            highlightRangeMode:          ListView.StrictlyEnforceRange
            preferredHighlightBegin:     0
            preferredHighlightEnd:       root.thumbW
            interactive:                 false

            Keys.onLeftPressed:   root.navigate(-1)
            Keys.onRightPressed:  root.navigate(1)
            Keys.onReturnPressed: root.applyWallpaper(root.wallpapers[listView.currentIndex])
            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_S && (event.modifiers & Qt.AltModifier)) {
                    root.deepMode = !root.deepMode
                    listProc._buf = []
                    listProc.running = false
                    listProc.running = true
                    event.accepted = true
                }
            }

            delegate: Item {
                id: delegate
                width:  root.thumbW
                height: listView.height
                required property string modelData
                required property int    index

                readonly property bool isSelected: index === listView.currentIndex

                Rectangle {
                    anchors.fill:  parent
                    color:         "transparent"
                    border.color:  delegate.isSelected ? root.accentColor : "transparent"
                    border.width:  root.borderPx
                    z:             2
                }

                Image {
                    id: thumb
                    anchors.fill:    parent
                    anchors.margins: delegate.isSelected ? root.borderPx : 0
                    source:          root.thumbPath(delegate.modelData)
                    fillMode:        Image.PreserveAspectCrop
                    clip:            true
                    asynchronous:    true
                    cache:           true

                    Rectangle {
                        anchors.fill: parent
                        color:        Qt.rgba(1, 1, 1, 0.06)
                        visible:      thumb.status !== Image.Ready
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z:            3
                    onClicked: {
                        listView.currentIndex = delegate.index
                        root.applyWallpaper(delegate.modelData)
                    }
                    // Mousewheel on individual thumbnails also scrolls
                    onWheel: event => {
                        if (event.angleDelta.y > 0)
                            root.navigate(-1)
                        else if (event.angleDelta.y < 0)
                            root.navigate(1)
                        event.accepted = true
                    }
                }
            }
        }
    }
}
