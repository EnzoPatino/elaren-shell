import QtQuick
import "../theme"

// Deslizador fino de la barra (volumen, brillo...). `value` va de 0 a 1;
// al arrastrar o hacer clic emite `moved` con el valor nuevo.
Item {
    id: root

    property real value: 0
    property bool dimmed: false
    property color accent: Theme.primary

    signal moved(real value)

    implicitWidth: 72
    implicitHeight: 24

    readonly property color tint: dimmed ? Theme.outline : accent

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: drag.containsMouse || drag.pressed ? 8 : 6
        radius: Theme.radius.full
        color: Qt.alpha(Theme.text, 0.12)

        Behavior on height { Anim { duration: Theme.anim.fast } }

        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, root.value))
            height: parent.height
            radius: Theme.radius.full
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(root.tint, 0.7) }
                GradientStop { position: 1; color: root.tint }
            }

            Behavior on width { Anim { duration: Theme.anim.fast } }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(1, root.value) * (parent.width - width)
        width: drag.pressed ? 14 : drag.containsMouse ? 12 : 10
        height: width
        radius: width / 2
        color: root.tint
        border.color: Qt.alpha("white", 0.35)
        border.width: drag.pressed ? 2 : 0

        Behavior on x { Anim { duration: Theme.anim.fast } }
        Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
        Behavior on color { CAnim {} }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.moved(Math.max(0, Math.min(1, event.x / width)))
        onPositionChanged: event => { if (pressed) root.moved(Math.max(0, Math.min(1, event.x / width))); }
    }
}
