// ┌─ NO TOCAR ───────────────────────────────────────────────────────────┐
// │ Gestor de fondos del entorno Hyprland: Elaren dibuja el fondo y la   │
// │ pestaña Fondos de la isla lo cambia. Funciona y está terminado: no   │
// │ lo cambies, ni lo reemplaces ni lo "simplifiques" sin que el autor   │
// │ lo pida explícitamente.                                              │
// │ Archivos: services/Wallpaper.qml, modules/background/Background.qml  │
// │ y modules/bar/WallpaperView.qml.                                     │
// └──────────────────────────────────────────────────────────────────────┘

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Fondo de pantalla. Lo dibuja Elaren porque, sin plasmashell, nadie lo hace.
// - Al arrancar entra con un zoom-out suave.
// - Al cambiar de wallpaper hace un fundido cruzado.
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

    // Capa que se mueve con el paralaje; las imágenes van dentro.
    Item {
        id: stage

        width: parent.width + root.parallaxRange
        height: parent.height
        x: -root.desktopIndex * Config.wallpaperParallax

        Behavior on x { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.emphasizedDecel } }

        // Dos capas para el fundido: `front` es la visible, `back` carga la nueva.
        property Image front: imageA
        property Image back: imageB
        // Fuente de cada capa tal como la dio Wallpaper (Image.source
        // normaliza la URL y no sirve para comparar).
        property string shown: ""
        property string loading: ""

        // Decodificar al tamaño en pantalla (con el margen del paralaje), en
        // píxeles físicos: un 8K original pesaría ~130 MB por capa.
        readonly property size decodeSize: width > 0 && height > 0
            ? Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            : Qt.size(1, 1)

        function show(source: string): void {
            if (!source || source === (loading || shown)) return;
            // Cambio durante el fundido: terminarlo ya, así `back` queda libre.
            if (crossfade.running) {
                crossfade.stop();
                finishCrossfade();
            }
            if (source === shown) {
                // Se volvió al fondo visible antes de que cargara el otro.
                loading = "";
                back.source = "";
                return;
            }
            loading = source;
            back.opacity = 0;
            back.source = source;
        }

        function onBackReady(): void {
            shown = loading;
            loading = "";
            back.z = 1;
            front.z = 0;
            crossfade.restart();
        }

        function finishCrossfade(): void {
            const old = front;
            back.opacity = 1;
            back.scale = 1;
            front = back;
            back = old;
            old.opacity = 0;
            old.source = "";
        }

        Image {
            id: imageA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: stage.decodeSize
            opacity: 0
            onStatusChanged: {
                if (stage.back !== imageA || stage.loading === "") return;
                if (status === Image.Ready) stage.onBackReady();
                else if (status === Image.Error) {
                    console.warn("wallpaper: no se pudo cargar", stage.loading);
                    stage.loading = "";
                }
            }
        }

        Image {
            id: imageB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: stage.decodeSize
            opacity: 0
            onStatusChanged: {
                if (stage.back !== imageB || stage.loading === "") return;
                if (status === Image.Ready) stage.onBackReady();
                else if (status === Image.Error) {
                    console.warn("wallpaper: no se pudo cargar", stage.loading);
                    stage.loading = "";
                }
            }
        }

        SequentialAnimation {
            id: crossfade
            ParallelAnimation {
                Anim { target: stage.back; property: "opacity"; from: 0; to: 1; duration: Theme.anim.extraSlow * 1.5 }
                Anim { target: stage.back; property: "scale"; from: 1.06; to: 1; duration: Theme.anim.extraSlow * 2; easing.bezierCurve: Theme.anim.emphasizedDecel }
            }
            ScriptAction { script: stage.finishCrossfade() }
        }

        Connections {
            target: Wallpaper
            function onSourceChanged() { stage.show(Wallpaper.source); }
        }

        Component.onCompleted: show(Wallpaper.source)
    }
}
