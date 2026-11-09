import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Reloj central: horas y minutos con dígitos que ruedan, los dos puntos
// "respiran" con cada segundo y la fecha va aparte. Clic: calendario.
BarGroup {
    id: root

    property bool calendarOpen: false

    padding: Theme.spacing.large
    clickable: true
    color: calendarOpen ? Theme.groupActive : Theme.group

    // Pulso de un segundo para los dos puntos
    property bool tick: false
    Timer {
        interval: 1000
        repeat: true
        running: Theme.anim.scale > 0
        onTriggered: root.tick = !root.tick
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        RollingText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.time.split(":")[0]
            color: Theme.text
            font.family: Theme.font.family
            font.pixelSize: Theme.font.large
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            text: ":"
            color: Theme.primary
            font.pixelSize: Theme.font.large
            font.weight: Font.Bold
            opacity: root.tick ? 0.35 : 1

            Behavior on opacity { Anim { duration: 600 } }
        }

        RollingText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.time.split(":")[1]
            color: Theme.text
            font.family: Theme.font.family
            font.pixelSize: Theme.font.large
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
    }

    // Divisor
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 14
        color: Qt.alpha(Theme.text, 0.18)
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: Time.shortDate
        color: root.calendarOpen ? Theme.primary : Theme.textMuted
        font.weight: Font.Medium
        animate: true
    }

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        font.pixelSize: 16
        color: Theme.textMuted
        animateChange: false
        rotation: root.calendarOpen ? 180 : 0

        Behavior on rotation { Anim { easing.bezierCurve: Theme.anim.expressive } }
    }
}
