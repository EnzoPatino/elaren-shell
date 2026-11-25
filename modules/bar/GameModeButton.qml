import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Botón del modo gaming (ver services/GameMode.qml).
// Clic: lo prende o lo apaga. Clic derecho: abre sus ajustes.
// Activo, la píldora se tiñe del acento y muestra "Gaming" (o "Auto" si lo
// prendió un juego con Feral GameMode). Como el modo apaga las animaciones,
// el estado activo se lee por color, no por movimiento.
BarGroup {
    id: root

    padding: Theme.spacing.normal
    clickable: true
    color: GameMode.active ? Theme.groupActive : Theme.group
    border.color: GameMode.active ? Qt.alpha(Theme.primary, 0.45) : Theme.glassBorder

    onClicked: GameMode.toggle()

    Behavior on color { CAnim {} }

    // `parent: root`: si no, el contenido va a la fila interna de BarGroup y
    // el clic derecho solo funcionaría sobre el icono.
    TapHandler {
        parent: root
        acceptedButtons: Qt.RightButton
        onTapped: Settings.show("gaming")
    }

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: "sports_esports"
        rotation: Theme.bar.upright
        font.pixelSize: Theme.font.icon
        color: GameMode.active ? Theme.primary : Theme.textMuted
    }

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: GameMode.active && !Theme.bar.vertical

        StyledText {
            rightPadding: 2
            text: GameMode.autoActive && !GameMode.manual ? "Auto" : "Gaming"
            color: Theme.primary
            font.pixelSize: Theme.font.small
            font.weight: Font.Bold
        }
    }
}
