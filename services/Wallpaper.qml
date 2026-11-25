// ┌─ NO TOCAR ───────────────────────────────────────────────────────────┐
// │ Gestor de fondos del entorno Hyprland: Elaren dibuja el fondo y la   │
// │ pestaña Fondos de la isla lo cambia. Funciona y está terminado: no   │
// │ lo cambies, ni lo reemplaces ni lo "simplifiques" sin que el autor   │
// │ lo pida explícitamente.                                              │
// │ Archivos: services/Wallpaper.qml, modules/background/Background.qml  │
// │ y modules/bar/WallpaperView.qml.                                     │
// └──────────────────────────────────────────────────────────────────────┘

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
    // Ruta final a una imagen, lista para usar en un Image (URL codificada).
    property string source: ""
    // La misma imagen como ruta común (sin file://), para comparar rutas.
    property string currentPath: ""

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

    // Algún escritorio de Plasma usa el plugin de skwd-wall: el fondo real
    // (también videos y escenas) lo sabe skwd-walld, no el Image= de Plasma.
    property bool plasmaUsesSkwd: false
    // skwd-walld dibuja el fondo, por su plugin de Plasma o en standalone.
    readonly property bool skwdDraws: !Config.wallpaper
        && (Config.wallpaperProvider === "skwd" || skwdStandalone || plasmaUsesSkwd)

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
        plasmaUsesSkwd = Object.values(plugins).includes("org.skwd.wall.plasma");
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

    // Ruta → URL file:// codificada: un `%`, `#` o `?` en el nombre no
    // rompe la URL ni se confunde con un escape.
    function toUrl(path: string): string {
        if (!path.startsWith("/")) return path;
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function setImage(path: string): void {
        currentPath = path.startsWith("file://") ? decodeURIComponent(path.slice(7)) : path;
        source = toUrl(currentPath);
    }

    // Paquete que se está resolviendo (o "" si ninguno).
    property string wantedPackage: ""

    function resolve(): void {
        const path = Config.wallpaper || configured;
        if (!path) {
            wantedPackage = "";
            currentPath = "";
            source = "";
        } else if (imageExt.test(path)) {
            // Un paquete que termine de resolverse después ya no manda.
            wantedPackage = "";
            setImage(path);
        } else {
            // Paquete de wallpaper (carpeta con contents/images/): usar la imagen más grande.
            wantedPackage = path.replace(/\/$/, "");
            if (!packageResolver.running) startPackage();
            // Si ya corría, onExited lanza el pedido nuevo.
        }
    }

    function startPackage(): void {
        packageResolver.requested = wantedPackage;
        packageResolver.command = ["sh", "-c",
            'ls -1 "$1"/contents/images/* 2>/dev/null | sort -V | tail -n 1', "sh", wantedPackage];
        packageResolver.running = true;
    }

    onConfiguredChanged: resolve()
    Component.onCompleted: resolve()

    // Elegir un fondo (Configuración o la pestaña Fondos) cambia Config.wallpaper.
    Connections {
        target: Config
        function onWallpaperChanged(): void { root.resolve(); }
    }

    // ── Elegir fondo (pestaña Fondos de la isla) ─────────────────────────
    // Carpeta con las imágenes para elegir: la de Configuración → Fondo o,
    // si está vacía, <Imágenes>/Wallpapers (xdg-user-dir, así vale igual con
    // la carpeta en español o en inglés).
    property string picturesDir: `${Quickshell.env("HOME")}/Pictures`
    readonly property string folder: (Config.wallpaperDir || `${picturesDir}/Wallpapers`).replace(/\/$/, "")

    Process {
        running: true
        command: ["xdg-user-dir", "PICTURES"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                if (dir) root.picturesDir = dir;
            }
        }
    }

    // Fondo elegido que espera turno: hasta saber quién dibuja el fondo, o
    // mientras el comando anterior (Plasma/skwd) sigue corriendo. Solo vale
    // el último: con clics rápidos gana la imagen elegida al final.
    property string pendingApply: ""

    // Pone `path` de fondo con quien lo esté dibujando.
    function apply(path: string): void {
        if (!path) return;
        if (!providerKnown || applier.running) {
            pendingApply = path;
            return;
        }
        pendingApply = "";
        if (path === currentPath) return;

        if (Config.wallpaperProvider === "skwd" || (Config.wallpaperProvider === "auto" && skwdStandalone)) {
            applier.command = ["skwd", "wall", "apply", JSON.stringify({ path: path, type: "static" })];
        } else if (Config.wallpaperProvider === "auto" && plasmaDesktop) {
            applier.command = ["plasma-apply-wallpaperimage", path];
        } else {
            if (Quickshell.env("ELAREN_WALLPAPER"))
                console.warn("wallpaper: ELAREN_WALLPAPER está definida y manda sobre el fondo elegido");
            Config.wallpaperSetting = path;
            return;
        }
        // Lo dibuja otro: un fondo elegido antes en Configuración taparía al
        // nuevo en la marca de la grilla y en el bloqueo.
        Config.wallpaperSetting = "";
        applier.path = path;
        console.info("wallpaper: aplicando", path, "con", applier.command[0]);
        applier.running = true;
    }

    onProviderKnownChanged: if (providerKnown && pendingApply) apply(pendingApply)

    Process {
        id: applier

        property string path: ""

        onExited: code => {
            if (code === 0) {
                // skwd no escribe el appletsrc y Plasma tarda en hacerlo:
                // se toma el fondo nuevo sin esperar a que el archivo cambie.
                root.configured = path;
            } else {
                console.warn("wallpaper: no se pudo aplicar el fondo,", command[0], "terminó con", code);
            }
            if (root.pendingApply) root.apply(root.pendingApply);
        }
    }

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

        property string requested: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const file = text.trim();
                // Si mientras tanto se eligió otro fondo, este resultado no vale.
                if (file && packageResolver.requested === root.wantedPackage) root.setImage(file);
            }
        }
        // Pedido nuevo llegado mientras corría: lanzarlo después de que se
        // procese la salida del anterior (que se descarta por `requested`).
        onExited: Qt.callLater(() => {
            if (root.wantedPackage && requested !== root.wantedPackage && !running) root.startPackage();
        })
    }
}
