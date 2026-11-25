import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Bluetooth: clic lo prende o lo apaga; clic derecho abre los dispositivos en
// Plasma. Al pasar el ratón se despliega lo que está conectado.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 24

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Bluetooth.icon
            rotation: Theme.bar.upright
            color: Bluetooth.connected ? Theme.primary
                 : Bluetooth.enabled ? Theme.text
                 : Theme.textMuted
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: touch.containsMouse && !Theme.bar.vertical

            StyledText {
                width: Math.min(implicitWidth, 140)
                elide: Text.ElideRight
                text: Bluetooth.summary
                color: Theme.textMuted
                font.pixelSize: Theme.font.small
                rightPadding: 2
            }
        }
    }

    StateLayer {
        id: touch
        anchors.margins: -2
        radius: Theme.radius.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? Bluetooth.openSettings() : Bluetooth.toggle()
    }
}
