import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    Theme   { id: theme }
    NiriIpc { id: niriIpc }

    QtObject {
        id: notifState
        property var list: []

        function add(notif) {
            var summary = notif.summary ? notif.summary.trim() : ""
            var body    = notif.body    ? notif.body.trim()    : ""
            if (summary === "" && body === "") return

            var imgUrl = notif.image || ""
            if (imgUrl === "") {
                var icon = notif.appIcon || ""
                var lc = icon.toLowerCase()
                var isScreenshot = lc.indexOf("screenshot") !== -1
                if (isScreenshot) {
                    if (icon.indexOf("file://") === 0) imgUrl = icon
                    else if (icon.indexOf("/") === 0)  imgUrl = "file://" + icon
                }
            }

            var arr = list.slice()
            arr.unshift({ notif: notif, time: new Date(), imageUrl: imgUrl })
            list = arr

            notif.trackedChanged.connect(function() {
                if (!notif.tracked) {
                    Qt.callLater(function() { notifState.removeById(notif.id) })
                }
            })
        }

        function removeById(id) {
            list = list.filter(function(n) { return n.notif.id !== id })
        }

        function clearAll() {
            for (var i = 0; i < list.length; i++) {
                try { list[i].notif.tracked = false } catch(e) {}
            }
            list = []
        }

        function clearByApp(appName) {
            var toRemove = []
            for (var i = 0; i < list.length; i++) {
                if (list[i].notif.appName === appName) {
                    try { list[i].notif.tracked = false } catch(e) {}
                    toRemove.push(list[i].notif.id)
                }
            }
            list = list.filter(function(n) {
                return toRemove.indexOf(n.notif.id) === -1
            })
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        imageSupported:   true
        onNotification: function(notif) {
            notif.tracked = true
            notifState.add(notif)
        }
    }

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

    // ── Bar + notification center + toasts (one set per screen) ──────────────
    Variants {
        model: Quickshell.screens

        Item {
            id: wrapper
            required property var modelData
            property var  thisScreen:      wrapper.modelData
            property bool notifCenterOpen: false
            property bool powerMenuOpen:   false
            property bool networkMenuOpen: false
			property bool calendarOpen:    false
			property bool mediaCenterOpen: false
            property bool dnd:             false

            // ── Mutual Exclusion Handlers ─────────────────────────────────────
            onNotifCenterOpenChanged: {
                if (notifCenterOpen) {
                    powerMenuOpen = false
                    networkMenuOpen = false
					calendarOpen = false
					mediaCenterOpen = false
                    pickerLoader.active = false
                }
            }

            onPowerMenuOpenChanged: {
                if (powerMenuOpen) {
                    notifCenterOpen = false
                    networkMenuOpen = false
					calendarOpen = false
					mediaCenterOpen = false
                    pickerLoader.active = false
                }
            }

            onNetworkMenuOpenChanged: {
                if (networkMenuOpen) {
                    notifCenterOpen = false
                    powerMenuOpen = false
					calendarOpen = false
					mediaCenterOpen = false
                    pickerLoader.active = false
                }
            }

			onMediaCenterOpenChanged: {
                if (mediaCenterOpen) {
                    notifCenterOpen = false
                    powerMenuOpen = false
                    networkMenuOpen = false
                    calendarOpen = false
                    pickerLoader.active = false
                }
            }
			
			onCalendarOpenChanged: {
                if (calendarOpen) {
                    notifCenterOpen = false
                    powerMenuOpen = false
					networkMenuOpen = false
					mediaCenterOpen = false
                    pickerLoader.active = false
                }
            }
            // ──────────────────────────────────────────────────────────────────

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
                            _cx = pt.x; _lines = filtered; _vis = true
                        } else { _vis = false }
                    }
                }

                PopupWindow {
                    id: tooltipWindow
                    visible:       tooltipBridge._vis
                                   && tooltipBridge._lines.length > 0
                                   && !wrapper.notifCenterOpen
                                   && !wrapper.powerMenuOpen
                                   && !wrapper.networkMenuOpen
                                   && !wrapper.calendarOpen
                    color:         "transparent"
                    anchor.window: bar
                    anchor.rect.x: Math.min(Math.max(0, tooltipBridge._cx - tooltipWindow.width / 2), bar.width - tooltipWindow.width)
                    anchor.rect.y: -tooltipWindow.height - 2
                    anchor.rect.width: 1
                    anchor.rect.height: 1
                    implicitWidth: tipRect.implicitWidth
                    implicitHeight: tipRect.implicitHeight

                    Rectangle {
                        id: tipRect
                        anchors.fill: parent
                        color: theme.background||"#1e1e2e"
                        border.color: theme.caution||"#fab387"
                        border.width: 1
                        radius: 3
                        implicitWidth: tipCol.implicitWidth + 20
                        implicitHeight: tipCol.implicitHeight + 14

                        Column {
                            id: tipCol
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: tooltipBridge._lines
                                Text {
                                    text: modelData ? modelData.toString() : ""
                                    font.family: "Monocraft"
                                    font.pointSize: 9
                                    font.weight: Font.Medium
                                    color: theme.foreground||"#cdd6f4"
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                    }
                }

                // ── Left ──────────────────────────────────────────────────────
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Item {
                        id: archArea
                        property bool _trayHovered: false
                        width: archIcon.implicitWidth
                        height: 26
                        Text {
                            id: archIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 8
                            rightPadding: 0
                            text: "\uF303"
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 19
                            color: theme.foreground||"#cdd6f4"
                            verticalAlignment: Text.AlignVCenter
                        }
                        Timer {
                            id: singleClickTimer
                            interval: 5
                            repeat: false
                            onTriggered: Qt.createQmlObject(
                                'import Quickshell.Io; Process{command:["bash", "/home/payton/scripts/quickshell/arch-icon.sh"];running:true}', bar)
                        }
                        Timer {
                            id: trayHideTimer
                            interval: 200
                            repeat: false
                            onTriggered: { if (trayItems.menuVisible) return; archArea._trayHovered = false }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: { trayHideTimer.stop(); archArea._trayHovered = true }
                            onExited: trayHideTimer.restart()
                            onClicked: function(mouse) { singleClickTimer.restart() }
                            onDoubleClicked: function(mouse) {
                                singleClickTimer.stop()
                                wrapper.notifCenterOpen = false
                                wrapper.powerMenuOpen = false
                                wrapper.networkMenuOpen = false
                                wrapper.calendarOpen = false
                                if (pickerLoader.active) { if (pickerLoader.item) pickerLoader.item.close() }
                                else pickerLoader.active = true
                            }
                        }
                    }

                    Tray {
                        id: trayItems
                        height: 26
                        barWindow: bar
                        trayVisible: archArea._trayHovered
                        onTrayEntered: { trayHideTimer.stop(); archArea._trayHovered = true }
                        onTrayExited: trayHideTimer.restart()
                        onMenuDismissed: trayHideTimer.restart()
                    }

                    BarSpacer { chars: " // " }
                    Workspaces { targetOutput: wrapper.thisScreen ? wrapper.thisScreen.name : "" }
                    BarSpacer { chars: " // " }
                    WindowTitle { }
                }

				Cava { 
						anchors.centerIn: parent
				        onToggleMediaCenter: wrapper.mediaCenterOpen = !wrapper.mediaCenterOpen
				}

                // ── Right ─────────────────────────────────────────────────────
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
					spacing: 0
					Recorder { barWindow: bar }
                    BarSpacer { chars: " \\\\ " }
                    HardwareStats { }
                    Network { 
                        onToggleMenu: wrapper.networkMenuOpen = !wrapper.networkMenuOpen
				    }
				    Battery {
                        onOpenPowerMenu: wrapper.powerMenuOpen = !wrapper.powerMenuOpen
                    }
                    BarSpacer { chars: " \\\\ " }
                    NotifBell {
                        centerOpen: wrapper.notifCenterOpen
                        notifCount: notifState.list.length
                        dnd:        wrapper.dnd
                        onToggleCenter: wrapper.notifCenterOpen = !wrapper.notifCenterOpen
                        onToggleDnd:    wrapper.dnd = !wrapper.dnd
                    }
                    Weather { }
                    
                    // Clickable clock wrapper
                    Item {
                        width: clockWidget.implicitWidth
                        height: 26
                        
                        Clock {
                            id: clockWidget
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wrapper.calendarOpen = !wrapper.calendarOpen
                        }
                    }
                }
            }

            // Panels
            NotificationCenter {
                targetScreen:  wrapper.thisScreen
                isOpen:        wrapper.notifCenterOpen
                notifList:     notifState.list
                dnd:           wrapper.dnd
                onRequestClose: wrapper.notifCenterOpen = false
                onDndToggled:   wrapper.dnd = !wrapper.dnd
                onClearAll:     notifState.clearAll()
                onDismissId:    function(id) { notifState.removeById(id) }
            }

            PowerMenu {
                targetScreen:   wrapper.thisScreen
                isOpen:         wrapper.powerMenuOpen
                onRequestClose: wrapper.powerMenuOpen = false
            }

            NetworkMenu {
                targetScreen:   wrapper.thisScreen
                isOpen:         wrapper.networkMenuOpen
                onRequestClose: wrapper.networkMenuOpen = false
            }

            CalendarMenu {
                targetScreen:   wrapper.thisScreen
                isOpen:         wrapper.calendarOpen
                onRequestClose: wrapper.calendarOpen = false
            }

			MediaCenter {
                targetScreen:   wrapper.thisScreen
                barWindow:      bar
                isOpen:         wrapper.mediaCenterOpen
                onRequestClose: wrapper.mediaCenterOpen = false
            }

			NotifToast {
                targetScreen: wrapper.thisScreen
                server:       notifServer
                dnd:          wrapper.dnd
            }

            // On-Screen Display Popups (Volume & Brightness)
            Osd {
                targetScreen: wrapper.thisScreen
            }
        }
    }
}
