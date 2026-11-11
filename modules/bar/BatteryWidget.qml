import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Batería: cambia de color según el nivel y "late" al enchufar el cargador.
// Al pasar el ratón muestra cuánto falta para vaciarse (o llenarse).
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

            // "Late" unas veces al enchufar el cargador y queda quieto: un
            // pulso infinito mantenía la barra redibujándose sin parar
            // mientras cargaba (justo cuando más importa gastar poco).
            SequentialAnimation {
                id: chargePulse
                loops: 3
                Anim { target: icon; property: "opacity"; to: 0.45; duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.standard }
                Anim { target: icon; property: "opacity"; to: 1; duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.standard }
            }

            // Aviso cuando la batería es crítica: un "latido" corto cada pocos
            // segundos (el resto del tiempo la barra no redibuja).
            SequentialAnimation on scale {
                running: Battery.critical && Theme.anim.scale > 0
                loops: Animation.Infinite
                alwaysRunToEnd: true
                Anim { to: 1.25; duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast }
                Anim { to: 1; duration: Theme.anim.normal }
                PauseAnimation { duration: 4000 }
            }

            Connections {
                target: Battery
                function onChargingChanged() {
                    if (Battery.charging && Theme.anim.scale > 0) {
                        chargePulse.restart();
                    } else {
                        chargePulse.stop();
                        icon.opacity = 1;
                    }
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Battery.level * 100) + "%"
            color: icon.color
            font.pixelSize: Theme.font.small
            font.features: { "tnum": 1 }
        }

        // Tiempo restante, al pasar el ratón
        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: hover.hovered && Battery.timeLeft > 0 && !Battery.full

            StyledText {
                leftPadding: 4
                text: (Battery.charging ? "llena en " : "") + SystemStats.formatDuration(Battery.timeLeft)
                color: Theme.textMuted
                font.pixelSize: Theme.font.small
                font.features: { "tnum": 1 }
            }
        }

        HoverHandler { id: hover }
    }
}
