import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Batería: cambia de color según el nivel y "late" mientras carga.
Reveal {
    id: root

    shown: Battery.available

    Row {
        spacing: 2

        MaterialIcon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.icon
            rotation: 90
            color: Battery.critical ? Theme.error
                 : Battery.low ? Theme.warning
                 : Battery.charging ? Theme.success
                 : Theme.text

            SequentialAnimation on opacity {
                running: Battery.charging && Theme.anim.scale > 0
                loops: Animation.Infinite
                alwaysRunToEnd: true
                Anim { to: 0.45; duration: Theme.anim.extraSlow * 1.5; easing.bezierCurve: Theme.anim.standard }
                Anim { to: 1; duration: Theme.anim.extraSlow * 1.5; easing.bezierCurve: Theme.anim.standard }
            }

            // Parpadeo de aviso cuando la batería es crítica
            SequentialAnimation on scale {
                running: Battery.critical && Theme.anim.scale > 0
                loops: Animation.Infinite
                alwaysRunToEnd: true
                Anim { to: 1.2; duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast }
                Anim { to: 1; duration: Theme.anim.normal }
                PauseAnimation { duration: 1500 }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Battery.level * 100) + "%"
            color: icon.color
            font.pixelSize: Theme.font.small
            font.features: { "tnum": 1 }
        }
    }
}
