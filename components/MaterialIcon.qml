import QtQuick
import "../theme"

// Icono de Material Symbols (por nombre de ligadura, p. ej. "volume_up").
// Al cambiar de icono hace un pequeño "pop" de escala.
Text {
    id: root

    property bool animateChange: true

    color: Theme.text
    font.family: Theme.font.icons
    font.pixelSize: Theme.font.icon
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color { CAnim {} }

    Behavior on text {
        enabled: root.animateChange
        SequentialAnimation {
            ParallelAnimation {
                Anim { target: root; property: "scale"; to: 0.4; duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.emphasizedAccel }
                Anim { target: root; property: "opacity"; to: 0; duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.emphasizedAccel }
            }
            PropertyAction {}
            ParallelAnimation {
                Anim { target: root; property: "scale"; to: 1; duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast }
                Anim { target: root; property: "opacity"; to: 1; duration: Theme.anim.fast }
            }
        }
    }
}
