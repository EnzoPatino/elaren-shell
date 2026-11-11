pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import "../../theme"
import "../../config"
import "../../components"

// Base de los widgets de escritorio. Vive dentro de la capa común
// (DesktopWidgets.qml), que le asigna `area`.
//
// - Posición guardada en Config (widget<Key>X / widget<Key>Y, fracción del
//   espacio libre), así se mantiene aunque cambie el tamaño del widget.
// - Se arrastra con el ratón (salvo Config.widgetsLocked). El arrastre es
//   puro QML dentro de una sola ventana: no se reubica ninguna superficie,
//   por eso va fluido. Mientras se mueve, la capa muestra guías e imanes.
// - Con Config.widgetCards va sobre una tarjeta de vidrio; si no, el
//   contenido lleva sombra para leerse sobre cualquier fondo.
Item {
    id: root

    required property string key
    // Capa contenedora (la asigna DesktopWidgets al crear el widget)
    property var area: null
    default property alias content: holder.data

    readonly property bool card: Config.widgetCards
    readonly property real s: Config.widgetScale
    readonly property int padding: card ? 22 : 16

    readonly property real posX: Math.max(0, Math.min(1, Config[`widget${key}X`] ?? 0))
    readonly property real posY: Math.max(0, Math.min(1, Config[`widget${key}Y`] ?? 0))
    readonly property real freeWidth: Math.max(0, (area?.width ?? 0) - width)
    readonly property real freeHeight: Math.max(0, (area?.height ?? 0) - height)

    // Estado del arrastre
    readonly property bool dragging: drag.dragging
    property real dragX: 0
    property real dragY: 0
    // Otro widget se está moviendo: este se atenúa para no distraer.
    readonly property bool dimmed: (area?.activeWidget ?? null) !== null && area.activeWidget !== root

    width: Math.ceil((holder.implicitWidth + padding * 2) * s)
    height: Math.ceil((holder.implicitHeight + padding * 2) * s)

    x: dragging ? dragX : Math.round(posX * freeWidth)
    y: dragging ? dragY : Math.round(posY * freeHeight)
    z: dragging ? 10 : 0

    opacity: dimmed ? 0.5 : 1

    // Al soltar, el widget se "asienta" en su lugar con una animación. Se
    // habilita después de aparecer, para que no entre volando desde una esquina.
    property bool settled: false
    Timer {
        interval: 400
        running: true
        onTriggered: root.settled = true
    }
    Behavior on x { enabled: root.settled && !root.dragging; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
    Behavior on y { enabled: root.settled && !root.dragging; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
    Behavior on opacity { Anim {} }

    // ── Arrastre ──────────────────────────────────────────────────────────
    MouseArea {
        id: drag

        property bool dragging: false
        property real grabX: 0
        property real grabY: 0

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Config.widgetsLocked ? Qt.ArrowCursor : dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: event => {
            if (Config.widgetsLocked || !root.area) {
                event.accepted = false;
                return;
            }
            grabX = event.x;
            grabY = event.y;
            root.dragX = root.x;
            root.dragY = root.y;
            dragging = true;
            root.area.beginDrag(root);
        }
        onPositionChanged: event => {
            if (!dragging) return;
            const p = mapToItem(root.area, event.x, event.y);
            const snapped = root.area.snap(root, p.x - grabX, p.y - grabY);
            root.dragX = snapped.x;
            root.dragY = snapped.y;
        }
        onReleased: finish()
        onCanceled: finish()

        function finish(): void {
            if (!dragging) return;
            Config[`widget${root.key}X`] = root.freeWidth > 0 ? root.dragX / root.freeWidth : 0;
            Config[`widget${root.key}Y`] = root.freeHeight > 0 ? root.dragY / root.freeHeight : 0;
            dragging = false;
            root.area.endDrag(root);
        }
    }

    Item {
        id: body

        width: holder.implicitWidth + root.padding * 2
        height: holder.implicitHeight + root.padding * 2
        // Se "levanta" un poco mientras se arrastra
        scale: root.s * (root.dragging ? 1.03 : 1)
        transformOrigin: Item.TopLeft
        opacity: 0

        Behavior on scale { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast } }

        // Entrada suave
        ParallelAnimation {
            running: true
            Anim { target: body; property: "opacity"; from: 0; to: 1; duration: Theme.anim.slow }
            Anim { target: holderTranslate; property: "y"; from: 14; to: 0; duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.expressive }
        }

        // Sombra que aparece al levantarlo
        RectangularShadow {
            anchors.fill: parent
            anchors.margins: 2
            radius: 26
            blur: 32
            spread: -4
            offset.y: 12
            color: Qt.alpha("black", 0.55)
            opacity: root.dragging ? 1 : 0

            Behavior on opacity { Anim { duration: Theme.anim.normal } }
        }

        // Tarjeta de vidrio (opcional)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            visible: root.card
            radius: 26
            color: Qt.alpha(Theme.surface, root.dragging ? 0.78 : 0.62)
            border.width: 1
            border.color: Qt.alpha("white", 0.08)

            Behavior on color { CAnim { duration: Theme.anim.normal } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha("white", 0.05) }
                    GradientStop { position: 0.5; color: "transparent" }
                }
            }

            // Foco de luz del color de acento que sigue al cursor sobre la
            // tarjeta. Solo existe con el ratón encima: en reposo no dibuja.
            ClippingRectangle {
                id: spotlight

                // Posición del ratón en coordenadas de la tarjeta (sin escala)
                readonly property real mx: drag.mouseX / root.s - 2
                readonly property real my: drag.mouseY / root.s - 2

                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                opacity: drag.containsMouse || root.dragging ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity { Anim { duration: Theme.anim.slow } }

                Shape {
                    anchors.fill: parent

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: spotlight.mx
                            centerY: spotlight.my
                            centerRadius: Math.max(spotlight.width, spotlight.height) * 0.75
                            focalX: centerX
                            focalY: centerY
                            GradientStop { position: 0; color: Qt.alpha(Theme.primary, root.dragging ? 0.2 : 0.13) }
                            GradientStop { position: 0.55; color: Qt.alpha(Theme.primary, 0.03) }
                            GradientStop { position: 1; color: "transparent" }
                        }

                        startX: 0
                        startY: 0
                        PathLine { x: spotlight.width; y: 0 }
                        PathLine { x: spotlight.width; y: spotlight.height }
                        PathLine { x: 0; y: spotlight.height }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }
        }

        // Contorno y asa al pasar el ratón / mientras se arrastra
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 26
            color: "transparent"
            border.width: root.dragging ? 2 : 1.5
            border.color: Qt.alpha(Theme.primary, root.dragging ? 0.9 : 0.55)
            opacity: (drag.containsMouse || root.dragging) && !Config.widgetsLocked ? 1 : 0

            Behavior on opacity { Anim { duration: Theme.anim.fast } }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                width: 26
                height: 26
                radius: 13
                color: Qt.alpha(Theme.primary, 0.18)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.dragging ? "open_with" : "drag_indicator"
                    font.pixelSize: 16
                    color: Theme.primary
                }
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
