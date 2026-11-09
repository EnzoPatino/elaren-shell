import QtQuick
import Quickshell
import "../theme"

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
    visible: progress > 0.001

    onOpenChanged: {
        progressAnim.easing.bezierCurve = open ? Theme.anim.expressive : Theme.anim.emphasizedAccel;
        progressAnim.duration = open ? Theme.anim.slow : Theme.anim.normal;
        progress = open ? 1 : 0;
    }

    Behavior on progress { Anim { id: progressAnim } }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cardWidth
        height: body.implicitHeight + root.padding * 2
        radius: Theme.radius.large
        color: Theme.surface
        border.color: Theme.outline
        border.width: 1

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

        Item {
            id: body
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
    }
}
