pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import "../theme"

// Disco de vinilo con la portada como etiqueta.
//
// - Gira con inercia: acelera al reproducir y frena despacio al pausar.
// - El reflejo de luz queda fijo mientras los surcos giran debajo.
// - El brazo se apoya sobre el disco al reproducir y se retira al pausar.
// - `level` (0..1, nivel de audio real) hace latir el halo.
// - Con la rueda del ratón "se rasca" el disco: emite `scratched(±1)`.
Item {
    id: root

    property bool spinning: false
    property url cover: ""
    property color accent: Theme.primary
    property real level: 0
    // Avance del tema (0..1): el brazo recorre el disco del borde al centro.
    property real progress: 0

    signal scratched(int direction)
    signal clicked()

    // Pequeño rebote al cambiar de tema
    function bump(): void {
        bumpAnim.restart();
    }

    readonly property real discSize: Math.min(width - armSpace, height)
    readonly property real armSpace: width * 0.14

    // 0 = quieto, 1 = velocidad de crucero. Se anima para dar inercia.
    property real speed: spinning ? 1 : 0
    Behavior on speed {
        NumberAnimation {
            duration: (root.spinning ? 900 : 1700) * Theme.anim.scale
            easing.type: root.spinning ? Easing.InOutQuad : Easing.OutCubic
        }
    }

    FrameAnimation {
        running: root.speed > 0.001 && Theme.anim.scale > 0
        onTriggered: disc.rotation = (disc.rotation + frameTime * 140 * root.speed) % 360
    }

    // Halo de color que late con el audio
    Rectangle {
        anchors.centerIn: disc
        width: root.discSize * (1.06 + root.level * 0.08)
        height: width
        radius: width / 2
        color: Qt.alpha(root.accent, 0.05 + root.level * 0.16)

        Behavior on color { CAnim { duration: Theme.anim.slow } }
    }

    Rectangle {
        id: disc

        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.discSize
        height: width
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#1d1e26" }
            GradientStop { position: 1; color: "#0d0e13" }
        }
        border.width: 1
        border.color: Qt.alpha("white", 0.08)

        SequentialAnimation on scale {
            id: bumpAnim
            running: false
            NumberAnimation { to: 0.93; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }

        // Surcos
        Repeater {
            model: 12

            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: disc.width * (0.94 - index * 0.04)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha("white", index % 3 === 0 ? 0.07 : 0.035)
            }
        }

        // Etiqueta: la portada
        ClippingRectangle {
            id: label
            anchors.centerIn: parent
            width: disc.width * 0.4
            height: width
            radius: width / 2
            color: Qt.darker(root.accent, 2.2)
            border.width: 3
            border.color: "#14151b"

            Image {
                id: art
                anchors.fill: parent
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(256, 256)
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity { Anim { duration: Theme.anim.slow } }
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "album"
                color: root.accent
                font.pixelSize: label.width * 0.4
                animateChange: false
            }
        }

        // Eje
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: "#d8d8de"
            border.width: 1
            border.color: "#00000080"
        }
    }

    // Reflejo fijo: no gira con el disco, así los surcos "pasan" por debajo.
    Shape {
        anchors.fill: disc
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: disc.width / 2
                centerY: disc.height / 2
                angle: 45
                GradientStop { position: 0.00; color: Qt.alpha("white", 0.0) }
                GradientStop { position: 0.08; color: Qt.alpha("white", 0.10) }
                GradientStop { position: 0.16; color: Qt.alpha("white", 0.0) }
                GradientStop { position: 0.50; color: Qt.alpha("white", 0.0) }
                GradientStop { position: 0.58; color: Qt.alpha("white", 0.07) }
                GradientStop { position: 0.66; color: Qt.alpha("white", 0.0) }
                GradientStop { position: 1.00; color: Qt.alpha("white", 0.0) }
            }

            PathAngleArc {
                centerX: disc.width / 2
                centerY: disc.height / 2
                radiusX: disc.width / 2
                radiusY: disc.height / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // Brazo del tocadiscos
    Item {
        id: arm

        x: disc.width - 2
        y: disc.y + disc.height * 0.02
        width: 1
        height: 1
        rotation: root.spinning ? 12 + 13 * Math.max(0, Math.min(1, root.progress)) : 3
        transformOrigin: Item.TopLeft

        Behavior on rotation {
            NumberAnimation {
                duration: (root.spinning ? 750 : 600) * Theme.anim.scale
                easing.type: root.spinning ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: 1.4
            }
        }

        // Varilla
        Rectangle {
            x: -2
            y: 0
            width: 4
            height: root.discSize * 0.6
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#9a9ca8" }
                GradientStop { position: 1; color: "#5d5f6a" }
            }
        }

        // Cápsula
        Rectangle {
            x: -6
            y: root.discSize * 0.6 - 4
            width: 12
            height: 20
            radius: 3
            rotation: -14
            color: "#c9cad3"
            border.width: 1
            border.color: "#00000060"
        }
    }

    // Pivote (no rota)
    Rectangle {
        x: arm.x - 9
        y: arm.y - 9
        width: 18
        height: 18
        radius: 9
        color: "#2a2b33"
        border.width: 2
        border.color: "#8d8f99"
    }

    TapHandler {
        onTapped: root.clicked()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    WheelHandler {
        target: null
        onWheel: event => {
            const direction = event.angleDelta.y > 0 ? -1 : 1;
            disc.rotation = (disc.rotation + direction * 35 + 360) % 360;
            root.scratched(direction);
        }
    }
}
