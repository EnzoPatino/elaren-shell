pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Fantasma: cúpula, falda ondulada y ojos. `look` (-1..1) mueve las pupilas
// hacia un costado (p. ej. hacia donde está el pacman).
Item {
    id: root

    property color color: "#ff5c7a"
    property real look: 0

    implicitWidth: 14
    implicitHeight: 15

    Behavior on look { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            startX: 0
            startY: root.width / 2
            // Cúpula
            PathArc { x: root.width; y: root.width / 2; radiusX: root.width / 2; radiusY: root.width / 2 }
            PathLine { x: root.width; y: root.height }
            // Falda en zigzag
            PathLine { x: root.width * 5 / 6; y: root.height - root.height * 0.18 }
            PathLine { x: root.width * 4 / 6; y: root.height }
            PathLine { x: root.width * 3 / 6; y: root.height - root.height * 0.18 }
            PathLine { x: root.width * 2 / 6; y: root.height }
            PathLine { x: root.width * 1 / 6; y: root.height - root.height * 0.18 }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: root.width / 2 }
        }
    }

    // Ojos
    Repeater {
        model: 2

        Rectangle {
            required property int index
            x: root.width * (index === 0 ? 0.16 : 0.54)
            y: root.height * 0.24
            width: root.width * 0.3
            height: root.height * 0.32
            radius: width / 2
            color: "white"

            Rectangle {
                width: parent.width * 0.55
                height: width
                radius: width / 2
                color: "#2240c8"
                x: (parent.width - width) / 2 + root.look * (parent.width - width) / 2
                y: parent.height - height - 0.5
            }
        }
    }
}
