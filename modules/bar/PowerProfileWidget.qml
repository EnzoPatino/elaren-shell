import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Perfil de energía (ver services/PowerProfile.qml). Clic: pasa al siguiente
// (Ahorro → Equilibrado → Rendimiento). Clic derecho: ajustes de energía de
// Plasma. Al pasar el ratón se despliega el nombre del perfil.
Item {
    id: root

    readonly property color tint: PowerProfile.current === "saver" ? Theme.success
                                : PowerProfile.current === "performance" ? Theme.warning
                                : Theme.text

    implicitWidth: row.implicitWidth
    implicitHeight: 24

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: PowerProfile.icon
            color: root.tint
            scale: touch.pressed ? 0.8 : 1

            Behavior on color { CAnim {} }
            Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: touch.containsMouse

            StyledText {
                text: PowerProfile.label(PowerProfile.current)
                    + (PowerProfile.degradation ? " · " + PowerProfile.degradation : "")
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
        onClicked: event => event.button === Qt.RightButton ? PowerProfile.openSettings() : PowerProfile.cycle()
    }
}
