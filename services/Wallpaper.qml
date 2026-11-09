pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Imagen de fondo. Por defecto lee el wallpaper que tengas en Plasma
// (y lo sigue si lo cambiás desde la configuración del escritorio).
Singleton {
    id: root

    // Ruta tal como figura en la configuración (archivo o paquete de wallpaper).
    property string configured: ""
    // Ruta final a una imagen, lista para usar en un Image.
    property string source: ""

    // skwd-wall dibuja el fondo por su cuenta (skwd-paper, con videos y escenas
    // de Wallpaper Engine); en ese caso Elaren no debe taparlo.
    property bool skwdStandalone: false
    property bool providerKnown: Config.wallpaperProvider !== "auto"
    readonly property bool external: Config.wallpaperProvider === "skwd"
        || (Config.wallpaperProvider === "auto" && skwdStandalone)
    // Elaren debe dibujar su propio fondo (una vez sabido quién lo hace).
    readonly property bool drawsOwn: providerKnown && !external

    readonly property string plasmaConfig: `${Quickshell.env("HOME")}/.config/plasma-org.kde.plasma.desktop-appletsrc`

    function parse(text: string): void {
        // Primer "Image=" dentro de un bloque [..][Wallpaper][org.kde.image][General]
        let inImageBlock = false;
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                inImageBlock = line.endsWith("[Wallpaper][org.kde.image][General]");
            } else if (inImageBlock && line.startsWith("Image=")) {
                configured = line.slice(6).replace(/^file:\/\//, "");
                return;
            }
        }
    }

    function resolve(): void {
        const path = Config.wallpaper || configured;
        if (!path) {
            source = "";
        } else if (/\.(jpe?g|png|webp|bmp|gif|avif|jxl|svg)$/i.test(path)) {
            source = path.startsWith("/") ? `file://${path}` : path;
        } else {
            // Paquete de wallpaper (carpeta con contents/images/): usar la imagen más grande.
            packageResolver.command = ["sh", "-c",
                'ls -1 "$1"/contents/images/* 2>/dev/null | sort -V | tail -n 1', "sh", path.replace(/\/$/, "")];
            packageResolver.running = true;
        }
    }

    onConfiguredChanged: resolve()
    Component.onCompleted: resolve()

    FileView {
        path: Config.wallpaper ? "" : root.plasmaConfig
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
    }

    // ¿skwd-walld está activo y sin el backend de Plasma? (ver scripts/run.sh)
    Process {
        id: skwdProbe
        running: Config.wallpaperProvider === "auto"
        command: ["sh", "-c",
            "systemctl --user is-active -q skwd-walld.service && systemctl --user show-environment | grep -qx SKWD_PLASMA_BACKEND=0"]
        onExited: code => {
            root.skwdStandalone = code === 0;
            root.providerKnown = true;
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: Config.wallpaperProvider === "auto"
        onTriggered: skwdProbe.running = true
    }

    Process {
        id: packageResolver
        stdout: StdioCollector {
            onStreamFinished: {
                const file = text.trim();
                if (file) root.source = `file://${file}`;
            }
        }
    }
}
