import QtQuick
import "../../theme"
import "../../components"

// Fila con interruptor.
RowBase {
    id: root

    property bool checked: false
    signal toggled(bool value)

    Rectangle {
        id: track
        width: 46
        height: 26
        radius: 13
        color: root.checked ? Theme.primary : Qt.alpha(Theme.text, 0.12)
        border.width: root.checked ? 0 : 1
        border.color: Qt.alpha(Theme.text, 0.15)

        Behavior on color { CAnim {} }

        Rectangle {
            id: knob
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 4
            width: touch.pressed ? 22 : 18
            height: 18
            radius: 9
            color: root.checked ? Theme.textOnPrimary : Theme.textMuted

            Behavior on x { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
            Behavior on width { Anim { duration: Theme.anim.fast } }
            Behavior on color { CAnim {} }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.checked ? "check" : "close"
                font.pixelSize: 12
                color: root.checked ? Theme.primary : Theme.surface
            }
        }

        MouseArea {
            id: touch
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.checked)
        }
    }
}
