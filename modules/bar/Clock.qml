import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../config"
import "../../services"

// Isla compacta del centro: avatar y reloj con dígitos que ruedan. Al pasar
// el ratón aparecen los segundos y los dos puntos "respiran" con cada uno.
// Clic: despliega la isla.
//
// El pulso va solo con el ratón encima: animarlo siempre obligaba a la barra
// entera a redibujarse ~60 % del tiempo.
BarGroup {
    id: root

    property bool open: false
    // Hacia dónde mira el avatar (lo calcula la barra según el cursor).
    property real lookX: 0
    property real lookY: 0

    padding: Config.barShowAvatar ? Theme.spacing.small : Theme.spacing.large
    clickable: true
    color: open ? Theme.groupActive : Theme.group

    HoverHandler { id: hover }

    SystemClock {
        id: seconds
        precision: SystemClock.Seconds
        enabled: hover.hovered
    }

    // Pulso de un segundo para los dos puntos (sincronizado con los segundos)
    readonly property bool tick: hover.hovered && Theme.anim.scale > 0 && seconds.date.getSeconds() % 2 === 1

    // Al abrir la isla el avatar cabecea.
    onOpenChanged: if (open) avatar.play("nod")

    Avatar {
        id: avatar
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.barShowAvatar
        width: Theme.bar.itemHeight - 6
        height: width
        shape: Config.barAvatarShape
        lookX: root.lookX
        lookY: root.lookY
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: Config.barShowAvatar ? Theme.spacing.small : 0
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

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        font.pixelSize: 16
        color: Theme.textMuted
        animateChange: false
        rotation: root.open ? 180 : 0

        Behavior on rotation { Anim { easing.bezierCurve: Theme.anim.expressive } }
    }
}
