import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Brillo de la pantalla. Rueda = ±5 %; el deslizador se despliega al pasar el
// ratón o, brevemente, cuando el brillo cambia (también desde el teclado).
// El sol gira un poco con cada cambio.
Reveal {
    id: root

    shown: Brightness.available

    Row {
        id: content

        readonly property bool expanded: hover.hovered || peek.running

        spacing: Theme.spacing.small

        HoverHandler { id: hover }

        Timer { id: peek; interval: 1600 }
        Timer { id: warmup; interval: 1500; running: true }

        Connections {
            target: Brightness
            function onRawChanged() { if (!warmup.running) peek.restart(); }
        }

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            text: Brightness.icon
            color: Theme.warning
            rotation: Brightness.value * 180

            Behavior on rotation { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: content.expanded

            PillSlider {
                value: Brightness.value
                accent: Theme.warning
                onMoved: value => Brightness.setValue(value)
            }
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: content.expanded

            StyledText {
                width: 32
                text: Math.round(Brightness.value * 100) + "%"
                color: Theme.textMuted
                font.pixelSize: Theme.font.small
                font.features: { "tnum": 1 }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => Brightness.change(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }
}
