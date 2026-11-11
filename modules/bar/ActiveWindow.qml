import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Icono y título de la ventana enfocada. Al cambiar de ventana el contenido
// entra con un fundido y un leve deslizamiento; si solo cambia el título
// (p. ej. una terminal con un spinner) se actualiza en el lugar, sin
// parpadear ni redibujar la barra con una animación.
Reveal {
    id: root

    property bool revealed: true
    property int revealDelay: 0
    property int maxWidth: 320

    readonly property var window: KWin.windows.find(w => w.id === KWin.activeWindow) ?? null

    readonly property string windowId: window?.id ?? ""
    readonly property string caption: KWin.captions[windowId] ?? window?.caption ?? ""

    shown: window !== null && revealed

    onWindowIdChanged: if (windowId !== "" && Theme.anim.scale > 0) swap.restart()

    BarGroup {
        padding: Theme.spacing.normal + 2
        revealed: root.revealed
        revealDelay: root.revealDelay
        color: "transparent"
        border.width: 0

        Image {
            id: appIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: root.window ? Apps.icon(root.window.appId) : ""
            smooth: true
        }

        StyledText {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxWidth)
            elide: Text.ElideRight
            text: root.caption
            color: Theme.textMuted
            transform: Translate { id: slide }
        }
    }

    ParallelAnimation {
        id: swap
        Anim { target: appIcon; property: "scale"; from: 0.6; to: 1; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast }
        Anim { target: appIcon; property: "opacity"; from: 0; to: 1; duration: Theme.anim.fast }
        Anim { target: slide; property: "x"; from: 8; to: 0; duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel }
        Anim { targets: [title]; property: "opacity"; from: 0; to: 1; duration: Theme.anim.normal }
    }
}
