import QtQuick
import "../theme"

// ColorAnimation con la duración y curva por defecto de Elaren.
ColorAnimation {
    duration: Theme.anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.anim.standard
}
