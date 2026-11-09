import QtQuick
import "../theme"

// NumberAnimation con la duración y curva por defecto de Elaren.
NumberAnimation {
    duration: Theme.anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.anim.standard
}
