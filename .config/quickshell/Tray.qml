import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: root
    height: 26

    property bool trayVisible: false
    signal trayEntered()
    signal trayExited()

    // Same width logic as original, but also gated on trayVisible
    width: (trayVisible && SystemTray.items.count > 0) ? trayRow.implicitWidth + 6 : 0
    clip: true

    Row {
        id: trayRow
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        leftPadding: SystemTray.items.count > 0 ? 4 : 0

        Repeater {
            model: SystemTray.items

            Item {
                required property SystemTrayItem modelData
                width:  18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source:       modelData.icon
                    smooth:       true
                    fillMode:     Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill:    parent
                    hoverEnabled:    true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: root.trayEntered()
                    onExited:  root.trayExited()
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) modelData.activate()
                        else modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
