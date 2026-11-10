import QtQuick
import "../../theme"
import "../../components"

// Base de una fila de opción: icono + título + descripción a la izquierda y
// el control (`control`) a la derecha. Se ilumina al pasar el ratón.
Item {
    id: root

    property string icon
    property string title
    property string description
    default property alias control: slot.data
    property real controlWidth: slot.childrenRect.width

    width: parent?.width ?? 0
    implicitHeight: Math.max(56, texts.implicitHeight + 20)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.normal
        color: "white"
        opacity: hover.hovered ? 0.035 : 0

        Behavior on opacity { Anim { duration: Theme.anim.fast } }
    }

    HoverHandler { id: hover }

    Rectangle {
        id: iconBox
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 11
        color: Qt.alpha(Theme.primary, 0.12)

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: 18
            color: Theme.primary
            animateChange: false
        }
    }

    Column {
        id: texts
        anchors.left: iconBox.visible ? iconBox.right : parent.left
        anchors.leftMargin: 12
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            width: parent.width
            text: root.title
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.textMuted
            font.pixelSize: Theme.font.small
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: root.controlWidth
        height: childrenRect.height
    }
}
