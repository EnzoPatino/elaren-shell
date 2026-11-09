import QtQuick
import Quickshell.Widgets
import "../theme"

// Capa de interacción: resalta al pasar el ratón y dibuja una onda (ripple)
// desde el punto donde se pulsa. Se coloca dentro del elemento a interactuar.
MouseArea {
    id: root

    property color color: Theme.text
    property real radius: (parent as Rectangle)?.radius ?? 0
    property bool disabled: false

    anchors.fill: parent
    enabled: !disabled
    hoverEnabled: true
    cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    onPressed: event => {
        const dx = Math.max(event.x, width - event.x);
        const dy = Math.max(event.y, height - event.y);
        const size = Math.sqrt(dx * dx + dy * dy) * 2;

        rippleOut.stop();
        ripple.width = size;
        ripple.x = event.x - size / 2;
        ripple.y = event.y - size / 2;
        ripple.opacity = 0.18;
        ripple.scale = 0;
        rippleIn.restart();
    }
    onReleased: rippleOut.restart()
    onCanceled: rippleOut.restart()

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.color
            opacity: root.disabled ? 0 : root.containsMouse ? 0.08 : 0

            Behavior on opacity { Anim { duration: Theme.anim.fast } }
        }

        Rectangle {
            id: ripple
            height: width
            radius: width / 2
            color: root.color
            opacity: 0
        }
    }

    Anim {
        id: rippleIn
        target: ripple
        property: "scale"
        to: 1
        duration: Theme.anim.slow
        easing.bezierCurve: Theme.anim.emphasizedDecel
    }

    Anim {
        id: rippleOut
        target: ripple
        property: "opacity"
        to: 0
        duration: Theme.anim.slow
    }
}
