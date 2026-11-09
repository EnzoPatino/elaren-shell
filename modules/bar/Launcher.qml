import QtQuick
import Quickshell
import "../../theme"
import "../../components"

// Botón de inicio: abre KRunner. El icono gira al pasar el ratón.
StyledRect {
    id: root

    property bool revealed: true

    implicitWidth: Theme.bar.itemHeight
    implicitHeight: Theme.bar.itemHeight
    radius: Theme.radius.full
    color: touch.containsMouse ? Theme.primary : Theme.surfaceContainer

    scale: revealed ? 1 : 0
    Behavior on scale { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast } }

    MaterialIcon {
        anchors.centerIn: parent
        text: "blur_on"
        animateChange: false
        color: touch.containsMouse ? Theme.textOnPrimary : Theme.primary
        rotation: touch.containsMouse ? 90 : 0
        scale: touch.pressed ? 0.8 : 1

        Behavior on rotation { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
        Behavior on scale { Anim { duration: Theme.anim.fast } }
    }

    StateLayer {
        id: touch
        color: Theme.textOnPrimary
        onClicked: Quickshell.execDetached(["krunner"])
    }
}
