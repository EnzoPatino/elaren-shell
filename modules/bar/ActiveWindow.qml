import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Icono y título de la ventana enfocada. Cambia con un fundido corto.
Reveal {
    id: root

    property bool revealed: true
    property int revealDelay: 0
    property int maxWidth: 320

    readonly property var window: KWin.windows.find(w => w.id === KWin.activeWindow) ?? null

    shown: window !== null && revealed

    BarGroup {
        padding: Theme.spacing.normal + 2
        revealed: root.revealed
        revealDelay: root.revealDelay
        color: "transparent"
        border.width: 0

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: root.window ? Apps.icon(root.window.appId) : ""
            smooth: true
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxWidth)
            elide: Text.ElideRight
            text: root.window?.caption ?? ""
            color: Theme.textMuted
            animate: true
        }
    }
}
