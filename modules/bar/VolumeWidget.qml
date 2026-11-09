import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Volumen. Rueda = ±5 %, clic en el icono = silenciar. El deslizador se
// despliega al pasar el ratón o, brevemente, cuando cambia el volumen.
Row {
    id: root

    readonly property bool expanded: hover.hovered || peek.running

    spacing: Theme.spacing.small

    HoverHandler { id: hover }

    Timer { id: peek; interval: 1600 }
    Timer { id: warmup; interval: 1500; running: true }

    Connections {
        target: Audio
        function onVolumeChanged() { if (!warmup.running) peek.restart(); }
        function onMutedChanged() { if (!warmup.running) peek.restart(); }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24

        MaterialIcon {
            anchors.centerIn: parent
            text: Audio.icon
            color: Audio.muted ? Theme.error : Theme.text
        }

        StateLayer {
            radius: Theme.radius.full
            onClicked: Audio.toggleMute()
        }
    }

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: root.expanded

        Item {
            implicitWidth: 72
            implicitHeight: 24

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: Theme.radius.full
                color: Theme.surfaceHigh

                Rectangle {
                    width: Math.max(height, parent.width * Math.min(1, Audio.volume))
                    height: parent.height
                    radius: Theme.radius.full
                    color: Audio.muted ? Theme.outline : Theme.primary

                    Behavior on width { Anim { duration: Theme.anim.fast } }
                    Behavior on color { CAnim {} }
                }
            }

            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(1, Audio.volume) * (parent.width - width)
                width: drag.pressed ? 14 : 10
                height: width
                radius: width / 2
                color: Audio.muted ? Theme.outline : Theme.primary

                Behavior on x { Anim { duration: Theme.anim.fast } }
                Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: event => Audio.setVolume(event.x / width)
                onPositionChanged: event => { if (pressed) Audio.setVolume(event.x / width); }
            }
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        text: Math.round(Audio.volume * 100) + "%"
        color: Theme.textMuted
        font.pixelSize: Theme.font.small
        font.features: { "tnum": 1 }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Audio.changeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
    }
}
