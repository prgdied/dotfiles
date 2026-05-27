import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    Theme   { id: theme }
    NiriIpc { id: niriIpc }

    // ── Wallpaper picker ──────────────────────────────────────────────────────
    IpcHandler {
        target: "wallpaper-picker"
        function open(): void {
            if (pickerLoader.active) {
                if (pickerLoader.item) pickerLoader.item.close()
            } else {
                pickerLoader.active = true
            }
        }
    }

    LazyLoader {
        id: pickerLoader
        active: false

        WallpaperPicker {
            onPickerClosed: pickerLoader.active = false
        }
    }

    // ── Bar (one per screen) ──────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        Item {
            id: wrapper
            required property var modelData
            property var thisScreen: wrapper.modelData

            PanelWindow {
                id: bar
                screen: wrapper.thisScreen

                anchors.bottom: true
                anchors.left:   true
                anchors.right:  true
                implicitHeight: 26

                WlrLayershell.layer:         WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace:     "quickshell"

                color: theme.background || "#1e1e2e"

                QtObject {
                    id: tooltipBridge
                    property bool _vis:   false
                    property var  _lines: []
                    property int  _cx:    0

                    function show(item, visible, lines) {
                        if (visible && lines && lines.length > 0) {
                            var filtered = lines.filter(function(l) {
                                return l && l.toString().trim() !== ""
                            })
                            if (filtered.length === 0) { _vis = false; return }
                            var pt = item.mapToItem(bar.contentItem, item.width / 2, 0)
                            _cx    = pt.x
                            _lines = filtered
                            _vis   = true
                        } else {
                            _vis = false
                        }
                    }
                }

                PopupWindow {
                    visible:       tooltipBridge._vis && tooltipBridge._lines.length > 0
                    color:         "transparent"
                    anchor.window: bar
                    anchor.rect.x: Math.min(
                        Math.max(0, tooltipBridge._cx - width / 2),
                        bar.width - width)
                    anchor.rect.y:      -height - 2
                    anchor.rect.width:  1
                    anchor.rect.height: 1
                    implicitWidth:  tipRect.implicitWidth
                    implicitHeight: tipRect.implicitHeight

                    Rectangle {
                        id: tipRect
                        anchors.fill:  parent
                        color:         theme.background || "#1e1e2e"
                        border.color:  theme.caution    || "#fab387"
                        border.width:  1
                        radius:        3
                        implicitWidth:  tipCol.implicitWidth  + 20
                        implicitHeight: tipCol.implicitHeight + 14
                        Column {
                            id: tipCol
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: tooltipBridge._lines
                                Text {
                                    text:           modelData ? modelData.toString() : ""
                                    font.family:    "Monocraft"
                                    font.pointSize: 9
                                    font.weight:    Font.Medium
                                    color:          theme.foreground || "#cdd6f4"
                                    wrapMode: Text.NoWrap
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }
                    }
                }

                // ── Left ──────────────────────────────────────────────────────
                Row {
                    id: leftRow
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    // Arch icon — hover here reveals the tray
                    Item {
                        id: archArea
                        property bool _trayHovered: false
                        // implicitWidth already includes leftPadding + rightPadding
                        width:  archIcon.implicitWidth
                        height: 26

                        Text {
                            id: archIcon
                            anchors.left:           parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 6; rightPadding: 4
                            text: "\uF303"
                            font.family:    "JetBrains Mono Nerd Font"
                            font.pixelSize: 19
                            color:          theme.foreground || "#cdd6f4"
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Timer delays single-click action so double-click can cancel it
                        Timer {
                            id: singleClickTimer
                            interval: 5
                            repeat:   false
                            onTriggered: {
                                Qt.createQmlObject(
                                    'import Quickshell.Io; Process{command:["kitty","--class","kitty-fastfetch","zsh","-c","fastfetch; exec zsh"];running:true}',
                                    bar)
                            }
                        }

                        // Small delay before hiding so mouse can travel to tray icons
                        Timer {
                            id: trayHideTimer
                            interval: 200
                            repeat:   false
                            onTriggered: archArea._trayHovered = false
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                trayHideTimer.stop()
                                archArea._trayHovered = true
                            }
                            onExited: trayHideTimer.restart()
                            onClicked: function(mouse) {
                                singleClickTimer.restart()
                            }
                            onDoubleClicked: function(mouse) {
                                singleClickTimer.stop()
                                if (pickerLoader.active) {
                                    if (pickerLoader.item) pickerLoader.item.close()
                                } else {
                                    pickerLoader.active = true
                                }
                            }
                        }
                    }

                    // Tray lives beside the arch icon in the Row so it
                    // participates in layout and pushes everything right.
                    // It collapses to zero width when hidden.
                    // NOTE: no anchors.verticalCenter — invalid inside a Row
                    Tray {
                        id: trayItems
                        height: 26
                        trayVisible: archArea._trayHovered

                        // Keep tray open while hovering over icons
                        onTrayEntered: {
                            trayHideTimer.stop()
                            archArea._trayHovered = true
                        }
                        onTrayExited: trayHideTimer.restart()
                    }

                    BarSpacer { chars: " // " }
                    Workspaces { targetOutput: wrapper.thisScreen ? wrapper.thisScreen.name : "" }
                    BarSpacer { chars: " // " }
                    WindowTitle { }
                }

                // ── Center ────────────────────────────────────────────────────
                Cava { anchors.centerIn: parent }

                // ── Right ─────────────────────────────────────────────────────
                Row {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    BarSpacer { chars: " \\\\ " }
                    HardwareStats { }
                    Battery { }
                    Network { }
                    BarSpacer { chars: " \\\\ " }
                    Notification { }
                    Weather { }
                    Clock { }
                }
            }
        }
    }
}
