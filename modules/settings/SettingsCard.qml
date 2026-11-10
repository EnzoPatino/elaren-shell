import QtQuick
import "../../theme"
import "../../components"

// Tarjeta que agrupa filas de opciones, con título opcional.
Column {
    id: root

    property string title
    property string icon
    default property alias rows: body.data

    width: parent?.width ?? 0
    spacing: 8

    Row {
        visible: root.title !== ""
        spacing: 8
        leftPadding: 4

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            font.pixelSize: 16
            color: Theme.primary
            animateChange: false
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title.toUpperCase()
            color: Theme.textMuted
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.3
        }
    }

    Rectangle {
        width: parent.width
        height: body.implicitHeight + 8
        radius: Theme.radius.large
        color: Qt.alpha(Theme.surfaceHigh, 0.45)
        border.width: 1
        border.color: Qt.alpha("white", 0.05)

        Column {
            id: body
            x: 4
            y: 4
            width: parent.width - 8
        }
    }
}
