import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Red: icono según el tipo de conexión y la señal del wifi. Al pasar el ratón
// se despliega el nombre de la red. Clic: configuración de red de Plasma.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 24

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.small

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            // Ondas que se expanden cuando la red cambia (se conecta o cae)
            Rectangle {
                id: pulse
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 12
                color: "transparent"
                border.color: Network.connected ? Theme.primary : Theme.error
                border.width: 2
                opacity: 0
                scale: 0.4
            }

            ParallelAnimation {
                id: pulseAnim
                Anim { target: pulse; property: "scale"; from: 0.4; to: 1.3; duration: Theme.anim.extraSlow }
                Anim { target: pulse; property: "opacity"; from: 0.8; to: 0; duration: Theme.anim.extraSlow }
            }

            Connections {
                target: Network
                function onTypeChanged() { if (Theme.anim.scale > 0) pulseAnim.restart(); }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: Network.icon
                color: Network.connected ? Theme.text : Theme.error
            }
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: touch.containsMouse && Network.available

            StyledText {
                width: Math.min(implicitWidth, 140)
                elide: Text.ElideRight
                text: Network.connected ? Network.name : "Sin conexión"
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
        onClicked: Network.openSettings()
    }
}
