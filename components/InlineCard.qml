import QtQuick
import Quickshell.Widgets
import "../theme"

// Tarjeta incrustada: la misma interfaz que AnimatedPopup (cardWidth,
// padding, decoration, open, dismissed) pero como un Item común, para que
// las vistas de los popups se puedan mostrar dentro de la isla de la barra.
Item {
    id: root

    property bool open: true
    property int cardWidth: 276
    property int padding: Theme.spacing.large
    default property alias content: body.data
    property alias decoration: decorationLayer.data
    property color cardColor: "transparent"
    property color borderColor: "transparent"

    signal dismissed()

    implicitWidth: cardWidth
    implicitHeight: body.implicitHeight + padding * 2

    ClippingRectangle {
        id: decorationLayer
        anchors.fill: parent
        radius: Theme.radius.large
        color: root.cardColor
        border.color: root.borderColor
        border.width: 1

        Behavior on border.color { CAnim { duration: Theme.anim.slow } }
    }

    Item {
        id: body
        x: root.padding
        y: root.padding
        width: root.cardWidth - root.padding * 2
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
    }
}
