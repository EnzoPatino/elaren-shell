import QtQuick
import QtQuick.Shapes
import "../theme"

// Anillo de progreso (0..1) con el arco animado.
Item {
    id: root

    property real value: 0
    property color color: Theme.primary
    property color trackColor: Theme.surfaceHigh
    property real thickness: 3

    property real animatedValue: Math.max(0, Math.min(1, value))
    Behavior on animatedValue { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.emphasizedDecel } }

    implicitWidth: 18
    implicitHeight: 18

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: (root.height - root.thickness) / 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor { CAnim {} }

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: (root.height - root.thickness) / 2
                startAngle: -90
                sweepAngle: 360 * root.animatedValue
            }
        }
    }
}
