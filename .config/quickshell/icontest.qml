import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        anchors.bottom: true
        anchors.left:   true
        anchors.right:  true
        implicitHeight: 70
        WlrLayershell.layer: WlrLayer.Top
        color: "#1e1e2e"

        Row {
            anchors.centerIn: parent
            spacing: 20

            // Ethernet candidates
            IcoCol { g: "\uDB80\uDF17"; l: "F0317\nlan"     }
            IcoCol { g: "\uDB81\uDEFF"; l: "F06FF\neth?"    }
            IcoCol { g: "\uDB82\uDE2D"; l: "F0A2D\nnet?"    }
            IcoCol { g: "\uDB80\uDE00"; l: "F0200\neth?"    }
            IcoCol { g: "\uDB81\uDD9F"; l: "F059F\neth?"    }
            IcoCol { g: "\uF0E8";       l: "F0E8\nsitemap"  }
            IcoCol { g: "\uF1E6";       l: "F1E6\nplug"     }
            IcoCol { g: "\uF796";       l: "F796\n?"        }

            Text { text: "|"; color: "#444"; font.pixelSize: 28; anchors.verticalCenter: parent.verticalCenter }

            // Notification icon candidates — show all 3 states
            IcoCol { g: "\uDB80\uDC9C"; l: "F009C\nnone";  c: "#cba6f7" }
            IcoCol { g: "\uDB80\uDD78"; l: "F0178\nhas";   c: "#fab387" }
            IcoCol { g: "\uDB82\uDE91"; l: "F0A91\ndnd";   c: "#89b4fa" }

            Text { text: "|"; color: "#444"; font.pixelSize: 28; anchors.verticalCenter: parent.verticalCenter }

            // Disconnected icon
            IcoCol { g: "\uEAD0"; l: "EAD0\nno-net"; c: "#f38ba8" }
        }

        component IcoCol: Column {
            property string g: ""
            property string l: ""
            property color  c: "white"
            spacing: 3
            Text {
                text: g
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 26
                color: parent.c
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: l
                font.pixelSize: 8
                color: "#aaa"
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
