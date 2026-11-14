import QtQuick
import Quickshell
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Vista "Inicio" de la isla: el avatar y el reloj en grande, con saludo y
// fecha.
Item {
    id: root

    property real lookX: 0
    property real lookY: 0

    implicitWidth: 460
    implicitHeight: 150

    readonly property int hour: Time.date.getHours()
    readonly property string greeting: hour < 6 ? "Buenas noches" : hour < 13 ? "Buen día" : hour < 20 ? "Buenas tardes" : "Buenas noches"
    readonly property string userName: {
        const name = Quickshell.env("USER") ?? "";
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    SystemClock {
        id: seconds
        precision: SystemClock.Seconds
        enabled: root.visible
    }

    // Resplandor de acento detrás del avatar
    Rectangle {
        x: avatar.x + avatar.width / 2 - width / 2
        y: avatar.y + avatar.height / 2 - height / 2
        width: avatar.width * 1.5
        height: width
        radius: width / 2
        color: Qt.alpha(Theme.primary, 0.1)
    }

    Avatar {
        id: avatar
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        width: 112
        height: 112
        shape: Config.barAvatarShape
        lookX: root.lookX
        lookY: root.lookY
        // Acá se ve grande: respira y se balancea. Clic: hace un gesto.
        idle: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: avatar.play(["spin", "bounce", "nod"][Math.floor(Math.random() * 3)])
        }
    }

    // Saluda al abrir la isla.
    Component.onCompleted: greet.start()
    Timer {
        id: greet
        interval: 250
        onTriggered: avatar.play("bounce")
    }

    Column {
        anchors.left: avatar.right
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            text: root.greeting + (root.userName ? ", " + root.userName : "")
            color: Theme.primary
            font.pixelSize: Theme.font.small
            font.weight: Font.Bold
            font.letterSpacing: 1.2
        }

        Row {
            spacing: 2

            RollingText {
                text: Time.time.split(":")[0]
                color: Theme.text
                font.family: Theme.font.family
                font.pixelSize: 56
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            StyledText {
                text: ":"
                color: Theme.primary
                font.pixelSize: 56
                font.weight: Font.Bold
            }

            RollingText {
                text: Time.time.split(":")[1]
                color: Theme.text
                font.family: Theme.font.family
                font.pixelSize: 56
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            RollingText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                leftPadding: 6
                text: Qt.formatDateTime(seconds.date, "ss")
                color: Theme.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.large + 3
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        StyledText {
            text: {
                const s = Time.longDate;
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: Theme.textMuted
            font.pixelSize: Theme.font.large
            font.weight: Font.Medium
        }
    }
}
