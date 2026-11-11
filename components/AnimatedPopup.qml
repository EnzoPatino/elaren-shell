import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../services"

// Tarjeta desplegable bajo un elemento de la barra. Se abre con rebote,
// se cierra acelerando y emite `dismissed` cuando el ratón sale un rato.
PopupWindow {
    id: root

    required property Item anchorItem
    property bool open: false
    property real progress: 0
    property int cardWidth: 276
    property int padding: Theme.spacing.large
    default property alias content: body.data
    // Capa detrás del contenido, recortada con las esquinas de la tarjeta
    // (p. ej. una imagen de fondo).
    property alias decoration: decorationLayer.data
    property color cardColor: Qt.alpha(Theme.surface, 0.96)
    property color borderColor: Theme.glassBorder

    signal dismissed()

    anchor.item: anchorItem
    anchor.rect.width: anchorItem.width
    anchor.rect.height: anchorItem.height
    anchor.rect.y: Theme.spacing.normal
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: cardWidth + 16
    implicitHeight: card.height + 16
    color: "transparent"
    // Durante una captura de pantalla desaparece sin animación y se cierra.
    visible: progress > 0.001 && !KWin.screenshotActive

    Connections {
        target: KWin
        function onScreenshotActiveChanged(): void {
            if (KWin.screenshotActive && root.open) root.dismissed();
        }
    }

    function updateProgress(): void {
        progressAnim.easing.bezierCurve = open ? Theme.anim.expressive : Theme.anim.emphasizedAccel;
        progressAnim.duration = open ? Theme.anim.slow : Theme.anim.normal;
        progress = open ? 1 : 0;
    }

    onOpenChanged: updateProgress()
    // Si se crea ya abierto (p. ej. tras una recarga), también debe mostrarse.
    Component.onCompleted: if (open) updateProgress()

    Behavior on progress { Anim { id: progressAnim } }

    // Vidrio: desenfoque real de KWin detrás de la tarjeta.
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: card.radius
    }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cardWidth
        height: body.implicitHeight + root.padding * 2
        radius: Theme.radius.large
        color: root.cardColor
        border.color: root.borderColor
        border.width: 1

        Behavior on border.color { CAnim { duration: Theme.anim.slow } }

        opacity: Math.min(1, root.progress)
        scale: 0.85 + 0.15 * root.progress
        transformOrigin: Item.Top
        transform: Translate { y: -16 * (1 - root.progress) }

        HoverHandler {
            id: hover
            onHoveredChanged: hovered ? closeTimer.stop() : closeTimer.restart()
        }

        Timer {
            id: closeTimer
            interval: 700
            onTriggered: if (!hover.hovered) root.dismissed()
        }

        ClippingRectangle {
            id: decorationLayer
            anchors.fill: parent
            anchors.margins: 1
            radius: card.radius - 1
            color: "transparent"
        }

        Item {
            id: body
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
    }
}
