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

    // Pasos de 2 %: el ruido de una lectura a otra (p. ej. la CPU cada 2 s) no
    // dispara una animación. Con CurveRenderer cada cuadro re-tesela el arco,
    // así que conviene animar solo cuando el cambio se ve.
    readonly property real steppedValue: Math.round(Math.max(0, Math.min(1, value)) * 50) / 50
    property real animatedValue: steppedValue
    Behavior on animatedValue { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel } }

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
