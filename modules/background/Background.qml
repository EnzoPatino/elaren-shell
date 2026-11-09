import QtQuick
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

    readonly property int desktopCount: Math.max(1, KWin.desktops.length)
    readonly property int desktopIndex: Math.max(0, KWin.currentDesktopIndex)
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

        function show(source: string): void {
            if (!source || source === front.source.toString()) return;
            back.source = source;
        }

        function onBackReady(): void {
            back.z = 1;
            front.z = 0;
            crossfade.restart();
        }

        Image {
            id: imageA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0
            onStatusChanged: if (status === Image.Ready && stage.back === imageA) stage.onBackReady()
        }

        Image {
            id: imageB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0
            onStatusChanged: if (status === Image.Ready && stage.back === imageB) stage.onBackReady()
        }

        SequentialAnimation {
            id: crossfade
            ParallelAnimation {
                Anim { target: stage.back; property: "opacity"; from: 0; to: 1; duration: Theme.anim.extraSlow * 1.5 }
                Anim { target: stage.back; property: "scale"; from: 1.06; to: 1; duration: Theme.anim.extraSlow * 2; easing.bezierCurve: Theme.anim.emphasizedDecel }
            }
            ScriptAction {
                script: {
                    const old = stage.front;
                    stage.front = stage.back;
                    stage.back = old;
                    old.opacity = 0;
                    old.source = "";
                }
            }
        }

        Connections {
            target: Wallpaper
            function onSourceChanged() { stage.show(Wallpaper.source); }
        }

        Component.onCompleted: show(Wallpaper.source)
    }
}
