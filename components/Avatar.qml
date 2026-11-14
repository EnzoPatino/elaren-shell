import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../theme"
import "../config"

// Avatar de la barra, según Configuración → Barra: un personaje dibujado por
// la shell (DrawnAvatar, generado a partir de una semilla, con ojos que
// siguen al cursor), un avatar de la galería de Plasma o la foto de ~/.face.
// Se recorta con una forma (círculo, squircle, flor o hexágono). Si una
// imagen no carga, un ícono con el acento.
//
// `lookX` / `lookY` (entre -1 y 1) indican hacia dónde está el cursor: el
// avatar se inclina y se corre apenas hacia ese lado, como si lo siguiera.
Item {
    id: root

    property string shape: "squircle"
    // "drawn" | "plasma" | "face"; por defecto, lo elegido en Configuración.
    property string source: Config.barAvatarSource
    property string seed: Config.barAvatarSeed
    property bool animated: true
    // Solo el personaje dibujado: respira y se balancea (donde se ve grande).
    property bool idle: false
    readonly property bool drawn: source === "drawn"

    // Gesto del personaje dibujado: "spin" | "nod" | "bounce".
    function play(name: string): void {
        if (character.item) character.item.play(name);
    }
    // Ruta local de la imagen (fuentes "plasma" y "face").
    property string path: source === "face"
        ? Quickshell.env("HOME") + "/.face"
        : Config.barAvatarImage
    property real lookX: 0
    property real lookY: 0

    implicitWidth: 24
    implicitHeight: 24

    readonly property bool hasPhoto: photo.status === Image.Ready

    // Puntos de la forma en coordenadas del ítem (para flor y hexágono).
    function outline(kind: string, w: real, h: real): var {
        const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2;
        const points = [];
        if (kind === "hexagon") {
            for (let i = 0; i <= 6; i++) {
                const a = Math.PI / 6 + i * Math.PI / 3;
                points.push(Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a)));
            }
        } else {
            // Flor de ocho pétalos: el radio ondula alrededor del centro.
            const steps = 96;
            for (let i = 0; i <= steps; i++) {
                const a = i / steps * 2 * Math.PI;
                const rr = r * (0.84 + 0.16 * Math.cos(8 * a));
                points.push(Qt.point(cx + rr * Math.cos(a), cy + rr * Math.sin(a)));
            }
        }
        return points;
    }

    Item {
        id: body
        anchors.fill: parent

        visible: !root.drawn
        rotation: root.lookX * 8
        transform: Translate {
            x: root.lookX * Math.max(1, root.width * 0.06)
            y: root.lookY * Math.max(1, root.height * 0.06)
            Behavior on x { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressive } }
            Behavior on y { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressive } }
        }
        Behavior on rotation { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressive } }

        // Máscara con la forma elegida (invisible: solo la usa el efecto).
        Item {
            id: mask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                visible: root.shape === "circle" || root.shape === "squircle"
                radius: root.shape === "circle" ? width / 2 : width * 0.3
                color: "black"
            }

            Shape {
                anchors.fill: parent
                visible: root.shape === "flower" || root.shape === "hexagon"
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: "black"
                    PathPolyline { path: root.outline(root.shape, mask.width, mask.height) }
                }
            }
        }

        // Imagen sobre un fondo suave: los avatares de Plasma tienen partes
        // transparentes.
        // `layer.enabled`: un Item oculto sin capa no se dibuja, y el efecto
        // de máscara recibiría una textura vacía (avatar invisible).
        Item {
            id: art
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                visible: !root.drawn
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.35) }
                    GradientStop { position: 1; color: Qt.alpha(Theme.secondary, 0.2) }
                }
            }

            Image {
                id: photo
                anchors.fill: parent
                visible: !root.drawn
                source: !root.drawn && root.path ? "file://" + encodeURI(root.path) : ""
                sourceSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        // Respaldo sin foto: la forma rellena con el acento y un ícono.
        Item {
            id: fallback
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.primary }
                    GradientStop { position: 1; color: Theme.secondary }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "person"
                color: Theme.textOnPrimary
                font.pixelSize: parent.height * 0.62
                animateChange: false
            }
        }

        MultiEffect {
            anchors.fill: parent
            visible: !root.drawn
            source: root.hasPhoto ? art : fallback
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    // Personaje dibujado: sin recorte de forma (gira en 3D y puede asomar
    // orejas o antenas) y sin la inclinación de las imágenes, porque ya mira
    // hacia el cursor por su cuenta.
    Loader {
        id: character
        anchors.fill: parent
        active: root.drawn
        sourceComponent: DrawnAvatar {
            seed: root.seed
            lookX: root.lookX
            lookY: root.lookY
            animated: root.animated
            idle: root.idle
        }
    }
}
