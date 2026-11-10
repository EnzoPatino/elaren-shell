import QtQuick
import "../../theme"
import "../../components"

// Fila con deslizador. `display` formatea el valor que se muestra.
RowBase {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property var display: v => Math.round(v * 100) / 100
    signal moved(real value)

    function snap(v: real): real {
        const clamped = Math.max(from, Math.min(to, v));
        return stepSize > 0 ? Math.round((clamped - from) / stepSize) * stepSize + from : clamped;
    }

    readonly property real fraction: (value - from) / Math.max(0.0001, to - from)

    Row {
        spacing: 12

        Item {
            id: slider
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            height: 26

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: drag.containsMouse || drag.pressed ? 8 : 6
                radius: height / 2
                color: Qt.alpha(Theme.text, 0.12)

                Behavior on height { Anim { duration: Theme.anim.fast } }

                Rectangle {
                    width: Math.max(parent.height, parent.width * root.fraction)
                    height: parent.height
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.darker(Theme.primary, 1.25) }
                        GradientStop { position: 1; color: Theme.primary }
                    }

                    Behavior on width { enabled: !drag.pressed; Anim { duration: Theme.anim.fast } }
                }
            }

            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                x: root.fraction * (parent.width - width)
                width: drag.pressed ? 20 : 16
                height: width
                radius: width / 2
                color: Theme.text
                border.width: 3
                border.color: Theme.primary

                Behavior on width { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }
                Behavior on x { enabled: !drag.pressed; Anim { duration: Theme.anim.fast } }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function apply(x: real): void {
                    root.moved(root.snap(root.from + (root.to - root.from) * Math.max(0, Math.min(1, x / width))));
                }
                onPressed: event => apply(event.x)
                onPositionChanged: event => { if (pressed) apply(event.x); }
            }

            WheelHandler {
                onWheel: event => {
                    const step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 20;
                    root.moved(root.snap(root.value + (event.angleDelta.y > 0 ? step : -step)));
                }
            }
        }

        // Valor actual
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 26
            radius: 8
            color: drag.pressed ? Qt.alpha(Theme.primary, 0.22) : Qt.alpha(Theme.text, 0.06)

            Behavior on color { CAnim { duration: Theme.anim.fast } }

            StyledText {
                anchors.centerIn: parent
                text: root.display(root.value)
                font.pixelSize: Theme.font.small
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: drag.pressed ? Theme.primary : Theme.text
            }
        }
    }
}
