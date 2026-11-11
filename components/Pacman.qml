import QtQuick
import QtQuick.Shapes

// Pacman dibujado con un sector circular. `mouth` es la mitad de la apertura
// de la boca en grados (0 = cerrada). Mira a la derecha; para mirar a la
// izquierda se espeja con `facingLeft`.
Item {
    id: root

    property real mouth: 35
    property color color: "#ffd23f"
    property bool facingLeft: false

    implicitWidth: 18
    implicitHeight: 18

    transform: Scale {
        origin.x: root.width / 2
        xScale: root.facingLeft ? -1 : 1
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            startX: root.width / 2
            startY: root.height / 2

            PathAngleArc {
                moveToStart: false
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2
                radiusY: root.height / 2
                startAngle: root.mouth
                sweepAngle: 360 - root.mouth * 2
            }
            PathLine { x: root.width / 2; y: root.height / 2 }
        }
    }

    // Ojo
    Rectangle {
        x: root.width * 0.5
        y: root.height * 0.2
        width: Math.max(2, root.width * 0.14)
        height: width
        radius: width / 2
        color: "#1b1b24"
    }
}
