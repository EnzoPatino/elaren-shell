// ┌─ NO TOCAR ───────────────────────────────────────────────────────────┐
// │ Gestor de fondos del entorno Hyprland: Elaren dibuja el fondo y la   │
// │ pestaña Fondos de la isla lo cambia. Funciona y está terminado: no   │
// │ lo cambies, ni lo reemplaces ni lo "simplifiques" sin que el autor   │
// │ lo pida explícitamente.                                              │
// │ Archivos: services/Wallpaper.qml, modules/background/Background.qml  │
// │ y modules/bar/WallpaperView.qml.                                     │
// └──────────────────────────────────────────────────────────────────────┘

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Fondo de pantalla. Lo dibuja Elaren porque, sin plasmashell, nadie lo hace.
// - Al cambiar de wallpaper hace la transición elegida (Config.wallpaperTransition):
//   fundido, zoom, deslizamiento, barrido o un círculo que nace de la isla.
// - Puede ser un video (fondo animado): sin sonido, en bucle, y en pausa en
//   modo gaming. Solo existe un reproductor por capa y se libera al salir.
// - Al cambiar de escritorio se desliza un poco (paralaje).
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "elaren-wallpaper"

    readonly property int desktopCount: Math.max(1, Compositor.desktops.length)
    readonly property int desktopIndex: Math.max(0, Compositor.currentDesktopIndex)
    readonly property real parallaxRange: (desktopCount - 1) * Config.wallpaperParallax

    readonly property var transitions: ["fade", "zoom", "slide", "wipe", "circle"]

    // Capa del fondo: una imagen o un video, con su propio recorte para el
    // barrido y el círculo. El recorte redondo (ClippingRectangle) dibuja a
    // una textura intermedia: solo se usa mientras dura el círculo.
    component Layer: Item {
        id: layer

        property string src: ""
        property bool isVideo: false
        // 0 → 1 durante la entrada (barrido y círculo)
        property real reveal: 1
        property string mode: "fade"
        // Centro del círculo, en coordenadas de la capa
        property point origin: Qt.point(width / 2, 0)
        readonly property bool circling: mode === "circle" && reveal < 1
        readonly property bool ready: isVideo ? (videoLoader.item?.ready ?? false) : image.status === Image.Ready
        readonly property bool failed: isVideo ? (videoLoader.status === Loader.Error || (videoLoader.item?.failed ?? false)) : image.status === Image.Error
        property size decodeSize: Qt.size(1, 1)

        // Sin anchors: el deslizamiento mueve `x`.
        width: parent.width
        height: parent.height
        opacity: 0

        Item {
            id: rectMask
            width: layer.mode === "wipe" ? layer.width * layer.reveal : layer.width
            height: layer.height
            clip: layer.mode === "wipe" && layer.reveal < 1
        }

        ClippingRectangle {
            id: circleMask
            readonly property real r: layer.reveal * Math.hypot(Math.max(layer.origin.x, layer.width - layer.origin.x),
                Math.max(layer.origin.y, layer.height - layer.origin.y))
            visible: layer.circling
            x: layer.origin.x - r
            y: layer.origin.y - r
            width: 2 * r
            height: 2 * r
            radius: r
            color: "transparent"
        }

        Item {
            id: content
            parent: layer.circling ? circleMask.contentItem : rectMask
            x: layer.circling ? -circleMask.x : 0
            y: layer.circling ? -circleMask.y : 0
            width: layer.width
            height: layer.height

            Image {
                id: image
                anchors.fill: parent
                visible: !layer.isVideo
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: layer.decodeSize
                source: layer.isVideo ? "" : layer.src
            }

            // Archivo aparte: si falta QtMultimedia solo falla el video, no el fondo.
            Loader {
                id: videoLoader
                anchors.fill: parent
                active: layer.isVideo && layer.src !== ""
                source: "VideoWallpaper.qml"
                onLoaded: item.source = Qt.binding(() => layer.src)
                onStatusChanged: if (status === Loader.Error) console.warn("wallpaper: no se pudo cargar el reproductor de video (¿falta QtMultimedia?)")
            }
        }
    }

    // Capa que se mueve con el paralaje; las capas del fondo van dentro.
    Item {
        id: stage

        width: parent.width + root.parallaxRange
        height: parent.height
        x: -root.desktopIndex * Config.wallpaperParallax

        Behavior on x { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.emphasizedDecel } }

        // Dos capas para la transición: `front` es la visible, `back` carga la nueva.
        property Layer front: layerA
        property Layer back: layerB
        // Clave (fuente + tipo) de cada capa, tal como la dio Wallpaper.
        property string shown: ""
        property string loading: ""
        property string mode: "fade"

        // Decodificar al tamaño en pantalla (con el margen del paralaje), en
        // píxeles físicos: un 8K original pesaría ~130 MB por capa.
        readonly property size decodeSize: width > 0 && height > 0
            ? Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            : Qt.size(1, 1)

        function key(): string {
            return Wallpaper.video ? `video:${Wallpaper.video}` : Wallpaper.source;
        }

        function show(): void {
            const k = key();
            if (!k || k === (loading || shown)) return;
            // Cambio durante la transición: terminarla ya, así `back` queda libre.
            if (transition.running) {
                transition.stop();
                finishTransition();
            }
            if (k === shown) {
                // Se volvió al fondo visible antes de que cargara el otro.
                loading = "";
                back.src = "";
                return;
            }
            loading = k;
            back.opacity = 0;
            back.isVideo = Wallpaper.video !== "";
            back.src = Wallpaper.video || Wallpaper.source;
        }

        function pickMode(): string {
            const wanted = Config.wallpaperTransition;
            if (root.transitions.includes(wanted)) return wanted;
            if (wanted === "random") return root.transitions[Math.floor(Math.random() * root.transitions.length)];
            return "fade";
        }

        function onBackReady(): void {
            shown = loading;
            loading = "";
            back.z = 1;
            front.z = 0;
            // El primer fondo entra con un fundido, sin barridos.
            mode = front.src === "" ? "fade" : pickMode();
            back.mode = mode;
            back.reveal = mode === "wipe" || mode === "circle" ? 0 : 1;
            // El círculo nace donde está la isla: arriba en el medio de la pantalla.
            back.origin = Qt.point(-stage.x + root.width / 2, 0);
            back.x = 0;
            back.scale = 1;
            front.x = 0;
            front.scale = 1;
            transition.restart();
        }

        function finishTransition(): void {
            const old = front;
            back.opacity = 1;
            back.scale = 1;
            back.x = 0;
            back.reveal = 1;
            front = back;
            back = old;
            old.opacity = 0;
            old.x = 0;
            old.scale = 1;
            old.src = "";
            old.isVideo = false;
        }

        Layer {
            id: layerA
            decodeSize: stage.decodeSize
            onReadyChanged: if (ready && stage.back === layerA && stage.loading !== "") stage.onBackReady()
            onFailedChanged: if (failed && stage.back === layerA && stage.loading !== "") stage.onBackFailed()
        }

        Layer {
            id: layerB
            decodeSize: stage.decodeSize
            onReadyChanged: if (ready && stage.back === layerB && stage.loading !== "") stage.onBackReady()
            onFailedChanged: if (failed && stage.back === layerB && stage.loading !== "") stage.onBackFailed()
        }

        function onBackFailed(): void {
            console.warn("wallpaper: no se pudo cargar", loading);
            loading = "";
        }

        readonly property int duration: Theme.anim.extraSlow * 1.5

        SequentialAnimation {
            id: transition

            ParallelAnimation {
                // Fundido: entra la nueva acercándose apenas.
                Anim { target: stage.back; property: "opacity"; from: 0; to: 1
                    duration: stage.mode === "wipe" || stage.mode === "circle" ? 0 : stage.duration }
                Anim { target: stage.back; property: "scale"
                    from: stage.mode === "zoom" ? 1.18 : stage.mode === "fade" ? 1.06 : 1; to: 1
                    duration: stage.duration * (stage.mode === "zoom" ? 1.2 : 2); easing.bezierCurve: Theme.anim.emphasizedDecel }
                // Zoom: la vieja se aleja mientras se desvanece por debajo.
                Anim { target: stage.front; property: "scale"; from: 1; to: stage.mode === "zoom" ? 0.9 : 1
                    duration: stage.duration; easing.bezierCurve: Theme.anim.emphasizedAccel }
                // Deslizamiento: la nueva empuja a la vieja hacia la izquierda.
                Anim { target: stage.back; property: "x"; from: stage.mode === "slide" ? root.width : 0; to: 0
                    duration: stage.duration; easing.bezierCurve: Theme.anim.emphasizedDecel }
                Anim { target: stage.front; property: "x"; from: 0; to: stage.mode === "slide" ? -root.width * 0.3 : 0
                    duration: stage.duration; easing.bezierCurve: Theme.anim.emphasizedDecel }
                // Barrido y círculo: se descubre la nueva.
                Anim { target: stage.back; property: "reveal"; from: stage.back.reveal; to: 1
                    duration: stage.duration; easing.bezierCurve: Theme.anim.emphasizedDecel }
            }
            ScriptAction { script: stage.finishTransition() }
        }

        Connections {
            target: Wallpaper
            function onSourceChanged() { Qt.callLater(stage.show); }
            function onVideoChanged() { Qt.callLater(stage.show); }
        }

        Component.onCompleted: show()
    }
}
