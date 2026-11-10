import QtQuick
import Quickshell
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Saludo según la hora del día, con la fecha y, si hay, el clima y el tema
// que está sonando.
DesktopWidget {
    id: root

    key: "Greeting"

    readonly property int hour: Time.date.getHours()
    readonly property string greeting: hour >= 5 && hour < 12 ? "Buenos días"
        : hour >= 12 && hour < 20 ? "Buenas tardes"
        : "Buenas noches"
    readonly property string icon: hour >= 6 && hour < 19 ? "light_mode" : "dark_mode"
    readonly property string user: {
        const name = Quickshell.env("USER") ?? "";
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    Row {
        spacing: 16

        // Sol o luna que flota suavemente
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 64
            radius: 32
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.35) }
                GradientStop { position: 1; color: Qt.alpha(Theme.secondary, 0.15) }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                font.pixelSize: 34
                color: Theme.primary

                SequentialAnimation on y {
                    running: Theme.anim.scale > 0
                    loops: Animation.Infinite
                    NumberAnimation { from: 13; to: 17; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 17; to: 13; duration: 2200; easing.type: Easing.InOutSine }
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: `${root.greeting},`
                color: Theme.textMuted
                font.pixelSize: 22
                font.weight: Font.Medium
                animate: true
            }
            StyledText {
                text: root.user
                font.pixelSize: 40
                font.weight: Font.Bold
            }
            StyledText {
                text: {
                    const parts = [];
                    if (Weather.current) parts.push(`${Math.round(Weather.current.temp)}° ${Weather.describe(Weather.current.code).toLowerCase()}`);
                    if (Media.playing) parts.push(`♪ ${Media.title}`);
                    return parts.join("  ·  ");
                }
                visible: text !== ""
                color: Theme.textMuted
                font.pixelSize: 15
                width: Math.min(implicitWidth, 420)
                elide: Text.ElideRight
                animate: true
            }
        }
    }
}
