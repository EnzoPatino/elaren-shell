import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Reloj central: horas y minutos con dígitos que ruedan y la fecha aparte.
// Al pasar el ratón aparecen los segundos y los dos puntos "respiran" con
// cada uno. Clic: calendario.
//
// El pulso va solo con el ratón encima: animarlo siempre obligaba a la barra
// entera a redibujarse ~60 % del tiempo.
BarGroup {
    id: root

    property bool calendarOpen: false

    padding: Theme.spacing.large
    clickable: true
    color: calendarOpen ? Theme.groupActive : Theme.group

    HoverHandler { id: hover }

    SystemClock {
        id: seconds
        precision: SystemClock.Seconds
        enabled: hover.hovered
    }

    // Pulso de un segundo para los dos puntos (sincronizado con los segundos)
    readonly property bool tick: hover.hovered && Theme.anim.scale > 0 && seconds.date.getSeconds() % 2 === 1

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
        // Segundos: solo al pasar el ratón (y solo entonces corre el reloj de segundos)
        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: hover.hovered

            RollingText {
                leftPadding: 2
                text: Qt.formatDateTime(seconds.date, "ss")
                color: Theme.primary
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
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
