pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Imagen de fondo. Por defecto lee el wallpaper que tengas en Plasma
// (y lo sigue si lo cambiás desde la configuración del escritorio).
// Si plasmashell está corriendo, Elaren no dibuja fondo: lo hace Plasma.
Singleton {
    id: root

    // Ruta tal como figura en la configuración (archivo o paquete de wallpaper).
    property string configured: ""
    // Ruta final a una imagen, lista para usar en un Image.
    property string source: ""

    // skwd-wall dibuja el fondo por su cuenta (skwd-paper, con videos y escenas
    // de Wallpaper Engine); en ese caso Elaren no debe taparlo.
    property bool skwdStandalone: false
    // plasmashell corriendo = su escritorio ya dibuja el fondo; poner otro
    // encima taparía el original.
    property bool plasmaDesktop: false
    property bool providerKnown: Config.wallpaperProvider !== "auto"
    readonly property bool external: Config.wallpaperProvider === "skwd"
        || (Config.wallpaperProvider === "auto" && (skwdStandalone || plasmaDesktop))
    // Elaren debe dibujar su propio fondo (una vez sabido quién lo hace).
    readonly property bool drawsOwn: providerKnown && !external

    readonly property string plasmaConfig: `${Quickshell.env("HOME")}/.config/plasma-org.kde.plasma.desktop-appletsrc`

    readonly property var imageExt: /\.(jpe?g|png|webp|bmp|gif|avif|jxl|svg)$/i

    // Imagen del plugin de skwd-wall (Assignments en JSON, una por salida).
    function skwdImage(json: string): string {
        try {
            const outputs = JSON.parse(json);
            for (const out of Object.values(outputs)) {
                const path = out?.wallpaper?.path ?? out?.assignment?.source?.path ?? "";
                if (imageExt.test(path)) return path;
            }
        } catch (e) {}
        return "";
    }

    function parse(text: string): void {
        // Un escritorio puede tener guardada config de varios plugins; solo vale
        // la del plugin que usa de verdad (wallpaperplugin=), si no se toma un
        // Image= viejo de org.kde.image y el fondo "cambia solo".
        const plugins = {};  // contenedor -> plugin activo
        const images = {};   // contenedor -> { plugin: ruta }
        let section = "";
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                section = line;
                continue;
            }
            const eq = line.indexOf("=");
            if (eq < 0) continue;
            const key = line.slice(0, eq), value = line.slice(eq + 1);
            let m = section.match(/^\[Containments\]\[(\d+)\]$/);
            if (m && key === "wallpaperplugin") {
                plugins[m[1]] = value;
                continue;
            }
            m = section.match(/^\[Containments\]\[(\d+)\]\[Wallpaper\]\[([^\]]+)\]\[General\]$/);
            if (!m) continue;
            let path = "";
            if (m[2] === "org.kde.image" && key === "Image")
                path = value.replace(/^file:\/\//, "");
            else if (m[2] === "org.skwd.wall.plasma" && key === "Assignments")
                path = skwdImage(value);
            if (!path) continue;
            if (!images[m[1]]) images[m[1]] = {};
            images[m[1]][m[2]] = path;
        }
        for (const [id, plugin] of Object.entries(plugins)) {
            const path = images[id]?.[plugin];
            if (path) {
                configured = path;
                return;
            }
        }
        // Ningún escritorio con imagen en su plugin activo (p. ej. un video):
        // conservar lo que haya, o caer al primer Image= conocido.
        if (!configured) {
            for (const per of Object.values(images)) {
                if (per["org.kde.image"]) {
                    configured = per["org.kde.image"];
                    return;
                }
            }
        }
    }

    function resolve(): void {
        const path = Config.wallpaper || configured;
        if (!path) {
            source = "";
        } else if (imageExt.test(path)) {
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

    // ¿Quién dibuja el fondo? (ver scripts/run.sh)
    //   plasma → plasmashell corriendo; skwd → skwd-walld sin backend de Plasma.
    Process {
        id: providerProbe
        running: Config.wallpaperProvider === "auto"
        command: ["sh", "-c", `
            pgrep -x plasmashell >/dev/null && echo plasma
            systemctl --user is-active -q skwd-walld.service \\
                && systemctl --user show-environment | grep -qx SKWD_PLASMA_BACKEND=0 && echo skwd
            true`]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n");
                root.plasmaDesktop = found.includes("plasma");
                root.skwdStandalone = found.includes("skwd");
                root.providerKnown = true;
            }
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: Config.wallpaperProvider === "auto"
        onTriggered: providerProbe.running = true
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
