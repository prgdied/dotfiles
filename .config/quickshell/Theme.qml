import QtQuick
import Quickshell.Io

Item {
    id: root

    property color background:  "#1e1e2e"
    property color foreground:  "#cdd6f4"
    property color color1:      "#cba6f7"
    property color color4:      "#89b4fa"
    property color color5:      "#f38ba8"
    property color color13:     "#cba6f7"
    property color color15:     "#a6e3a1"
    property color caution:     "#fab387"
    property color warning:     "#f9e2af"
    property color misc:        "#94e2d5"

    property string fontMain:   "Monocraft"
    property string fontMono:   "JetBrains Mono Nerd Font"
    property int    fontSize:   11
    property int    fontSizePx: 15

    FileView {
        id: walFile
        path: "/home/payton/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: walFile.reload()
        onLoaded: root._parseWal(walFile.text())
    }

    function _parseWal(text) {
        try {
            var data = JSON.parse(text)
            var c = data.colors
            var s = data.special
            if (!c || !s) return
            if (s.background) root.background = s.background
            if (s.foreground) root.foreground  = s.foreground
            if (c.color1)     root.color1      = c.color1
            if (c.color4)     root.color4      = c.color4
            if (c.color5)     root.color5      = c.color5
            if (c.color13)    root.color13     = c.color13
            if (c.color15)    root.color15     = c.color15
            if (c.color9)     root.caution     = c.color9
            if (c.color3)     root.warning     = c.color3
            if (c.color6)     root.misc        = c.color6
        } catch(e) {
            console.warn("Theme: parse error:", e)
        }
    }
}
