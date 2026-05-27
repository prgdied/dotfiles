import QtQuick

Item {
    property string chars: " "
    implicitWidth:  spacerText.implicitWidth
    implicitHeight: 26

    Text {
        id: spacerText
        anchors.centerIn: parent
        text:           chars
        font.family:    theme.fontMono   || "JetBrains Mono Nerd Font"
        font.pointSize: theme.fontSize   || 11
        font.weight:    Font.Medium
        color:          theme.foreground || "#cdd6f4"
        verticalAlignment: Text.AlignVCenter
    }
}
