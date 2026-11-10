pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"

// Base de los widgets de escritorio.
//
// - Ventana propia en la capa "Bottom": encima del fondo, debajo de las ventanas.
// - Posición guardada en Config (widget<Key>X / widget<Key>Y, fracción del
//   espacio libre), así se mantiene aunque cambie el tamaño del widget.
// - Se arrastra con el ratón (salvo Config.widgetsLocked).
// - Con Config.widgetCards va sobre una tarjeta de vidrio; si no, el
//   contenido lleva sombra para leerse sobre cualquier fondo.
PanelWindow {
    id: root

    required property string key
    default property alias content: holder.data
    property bool interactive: false      // el widget tiene botones propios

    readonly property bool card: Config.widgetCards
    readonly property real s: Config.widgetScale
    readonly property int padding: card ? 22 : 16

    readonly property real posX: Config[`widget${key}X`] ?? 0
    readonly property real posY: Config[`widget${key}Y`] ?? 0

    readonly property real screenWidth: screen?.width ?? 1920
    readonly property real screenHeight: (screen?.height ?? 1080) - Theme.bar.height
    readonly property real freeWidth: Math.max(0, screenWidth - implicitWidth)
    readonly property real freeHeight: Math.max(0, screenHeight - implicitHeight)

    property bool dragging: false
    property real dragLeft: 0
    property real dragTop: 0

    anchors {
        top: true
        left: true
    }
    margins.left: dragging ? dragLeft : Math.round(Math.max(0, Math.min(1, posX)) * freeWidth)
    margins.top: dragging ? dragTop : Math.round(Math.max(0, Math.min(1, posY)) * freeHeight)

    implicitWidth: Math.ceil((holder.implicitWidth + padding * 2) * s)
    implicitHeight: Math.ceil((holder.implicitHeight + padding * 2) * s)

    color: "transparent"
    // Respeta la zona de la barra (no queda debajo de ella) sin reservar espacio.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "elaren-widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── Arrastre ──────────────────────────────────────────────────────────
    MouseArea {
        id: drag

        property real pressX: 0
        property real pressY: 0

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Config.widgetsLocked ? Qt.ArrowCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: event => {
            if (Config.widgetsLocked) {
                event.accepted = false;
                return;
            }
            pressX = event.x;
            pressY = event.y;
            root.dragLeft = root.margins.left;
            root.dragTop = root.margins.top;
            root.dragging = true;
        }
        // La ventana se mueve con el ratón, así que se suma el desplazamiento
        // respecto del punto donde se agarró.
        onPositionChanged: event => {
            if (!pressed || !root.dragging) return;
            root.dragLeft = Math.max(0, Math.min(root.freeWidth, root.dragLeft + event.x - pressX));
            root.dragTop = Math.max(0, Math.min(root.freeHeight, root.dragTop + event.y - pressY));
        }
        onReleased: {
            if (!root.dragging) return;
            Config[`widget${root.key}X`] = root.freeWidth > 0 ? root.dragLeft / root.freeWidth : 0;
            Config[`widget${root.key}Y`] = root.freeHeight > 0 ? root.dragTop / root.freeHeight : 0;
            root.dragging = false;
        }
    }

    Item {
        id: body

        width: holder.implicitWidth + root.padding * 2
        height: holder.implicitHeight + root.padding * 2
        scale: root.s * (drag.pressed && !Config.widgetsLocked ? 0.97 : 1)
        transformOrigin: Item.TopLeft
        opacity: 0

        Behavior on scale { Anim { duration: Theme.anim.fast } }

        // Entrada suave
        ParallelAnimation {
            running: true
            Anim { target: body; property: "opacity"; from: 0; to: 1; duration: Theme.anim.slow }
            Anim { target: holderTranslate; property: "y"; from: 14; to: 0; duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.expressive }
        }

        // Tarjeta de vidrio (opcional)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            visible: root.card
            radius: 26
            color: Qt.alpha(Theme.surface, 0.62)
            border.width: 1
            border.color: Qt.alpha("white", 0.08)

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha("white", 0.05) }
                    GradientStop { position: 0.5; color: "transparent" }
                }
            }
        }

        // Contorno y asa al pasar el ratón (si se puede mover)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 26
            color: "transparent"
            border.width: 1.5
            border.color: Qt.alpha(Theme.primary, 0.6)
            opacity: (drag.containsMouse || drag.pressed) && !Config.widgetsLocked ? 1 : 0

            Behavior on opacity { Anim { duration: Theme.anim.fast } }

            MaterialIcon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                text: "drag_indicator"
                font.pixelSize: 16
                color: Theme.primary
                animateChange: false
            }
        }

        Item {
            id: holder

            x: root.padding
            y: root.padding
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            transform: Translate { id: holderTranslate }

            // Sin tarjeta, una sombra suave hace legible el texto sobre cualquier fondo.
            layer.enabled: !root.card
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha("black", 0.75)
                shadowBlur: 0.7
                shadowVerticalOffset: 2
                autoPaddingEnabled: true
            }
        }
    }
}
