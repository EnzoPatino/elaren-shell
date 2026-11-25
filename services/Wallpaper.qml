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
import "../theme"

// Imagen de fondo. Por defecto lee el wallpaper que tengas en Plasma
// (y lo sigue si lo cambiás desde la configuración del escritorio).
// Si plasmashell está corriendo, Elaren no dibuja fondo: lo hace Plasma.
Singleton {
    id: root

    // Ruta tal como figura en la configuración (archivo o paquete de wallpaper).
    property string configured: ""
    // Ruta final a una imagen, lista para usar en un Image (URL codificada).
    // Con un fondo animado es su cuadro fijo (para colores y bloqueo).
    property string source: ""
    // Fondo animado que dibuja Elaren (URL de un video) o "" si es una imagen.
    property string video: ""
    // El fondo puesto como ruta común (sin file://), para comparar rutas.
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
    readonly property var videoExt: /\.(mp4|webm|mkv|mov|m4v)$/i

    // skwd-wall aplica los fondos elegidos: lo dibuja él (standalone) o su
    // plugin de Plasma. Entonces también hay videos y escenas de Wallpaper Engine.
    // El plugin de Plasma cuenta solo con plasmashell corriendo: en Hyprland el
    // appletsrc sigue ahí, pero ese plugin no dibuja nada.
    readonly property bool viaSkwd: Config.wallpaperProvider === "skwd"
        || (Config.wallpaperProvider === "auto" && (skwdStandalone || (plasmaDesktop && plasmaUsesSkwd)))
    // Quien dibuja puede mostrar videos: skwd-wall o Elaren.
    readonly property bool animatedSupported: viaSkwd || drawsOwn
    readonly property string helm: `${Quickshell.env("HOME")}/.local/bin/skwd-helm`

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
        video = "";
    }

    // Fondo animado: el video (solo lo reproduce Elaren si dibuja el fondo) y
    // un cuadro fijo para colores y bloqueo (la vista previa de skwd o la
    // miniatura propia).
    function setAnimated(path: string): void {
        currentPath = path;
        const entry = skwdIndex[path];
        const own = thumbsReady[path] ? `${thumbDir}/${Qt.md5(path)}.jpg` : "";
        const still = entry?.preview || entry?.thumb || own;
        source = still ? toUrl(still) : "";
        video = drawsOwn && videoExt.test(path) ? toUrl(path) : "";
        if (!still && videoExt.test(path)) requestThumb(path);
    }

    // Paquete que se está resolviendo (o "" si ninguno).
    property string wantedPackage: ""

    function resolve(): void {
        // skwd-wall sabe qué hay puesto de verdad (también videos y escenas,
        // que no figuran como Image= en Plasma).
        const path = Config.wallpaper || (viaSkwd ? skwdCurrent : "") || configured;
        if (!path) {
            wantedPackage = "";
            currentPath = "";
            source = "";
            video = "";
        } else if (videoExt.test(path) || (skwdIndex[path] && skwdIndex[path].kind !== "image")) {
            wantedPackage = "";
            setAnimated(path);
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
    onSkwdCurrentChanged: resolve()
    onViaSkwdChanged: {
        resolve();
        refreshSkwdIndex();
    }
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

        if (viaSkwd) {
            // También con Plasma: su plugin de skwd-wall lo muestra. Con
            // plasma-apply-wallpaperimage se cambiaría el plugin por el de imagen.
            applier.command = [helm, "apply", path];
        } else if (Config.wallpaperProvider === "auto" && plasmaDesktop) {
            if (!imageExt.test(path)) {
                console.warn("wallpaper: Plasma solo muestra imágenes; para videos, que dibuje Elaren o skwd-wall");
                return;
            }
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

    onProviderKnownChanged: {
        if (providerKnown && pendingApply) apply(pendingApply);
        refreshSkwdIndex();
    }

    Process {
        id: applier

        property string path: ""

        onExited: code => {
            if (code === 0) {
                // skwd no escribe el appletsrc y Plasma tarda en hacerlo:
                // se toma el fondo nuevo sin esperar a que el archivo cambie.
                if (root.viaSkwd) root.skwdCurrent = path;
                else root.configured = path;
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

    // ── Lo que tiene puesto skwd-wall ────────────────────────────────────
    property string skwdCurrent: ""

    function refreshSkwdCurrent(): void {
        if (viaSkwd && !skwdProbe.running) skwdProbe.running = true;
    }

    Process {
        id: skwdProbe
        command: [root.helm, "current", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outs = JSON.parse(text).outputs ?? [];
                    const out = outs.find(o => o.connected) ?? outs[0];
                    const path = out?.path || out?.current || "";
                    if (path) root.skwdCurrent = path;
                } catch (e) {}
            }
        }
    }

    // Eventos del daemon (cambio de fondo desde su selector, playlists…):
    // cada línea pide releer el estado, agrupadas por el Timer.
    Process {
        running: root.viaSkwd
        command: [root.helm, "watch"]
        stdout: SplitParser {
            onRead: {
                skwdDebounce.restart();
                skwdIndexDebounce.restart();
            }
        }
        onRunningChanged: if (running) root.refreshSkwdCurrent()
    }

    Timer {
        id: skwdDebounce
        interval: 300
        onTriggered: root.refreshSkwdCurrent()
    }

    // ── Miniaturas de skwd-wall ──────────────────────────────────────────
    // ruta → { kind: "image" | "video" | "scene", thumb, preview }. Solo sirve
    // para tomar sus miniaturas (también de videos) y sus escenas; las
    // carpetas se recorren de verdad (ver browse). Se lee al arrancar y
    // cuando el daemon avisa cambios, no cada vez que se abre la pestaña.
    property var skwdIndex: ({})
    readonly property string thumbDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/elaren/wallpaper-thumbs`
    readonly property var skwdScenes: Object.keys(skwdIndex).filter(p => skwdIndex[p].kind === "scene")

    function refreshSkwdIndex(): void {
        if (viaSkwd && !skwdLister.running) skwdLister.running = true;
    }

    Timer {
        id: skwdIndexDebounce
        interval: 2000
        onTriggered: root.refreshSkwdIndex()
    }

    Process {
        id: skwdLister
        command: [root.helm, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const index = {};
                try {
                    for (const w of JSON.parse(text).wallpapers ?? []) {
                        const path = w.video_file || w.name || "";
                        if (!path || w.hidden) continue;
                        index[path] = {
                            kind: w.type === "static" ? "image" : w.type === "video" ? "video" : "scene",
                            thumb: w.thumb_sm || w.thumb || "",
                            preview: w.preview || w.thumb || ""
                        };
                    }
                } catch (e) {
                    console.warn("wallpaper: no se pudo leer la biblioteca de skwd-wall");
                }
                root.skwdIndex = index;
                root.resolve();
            }
        }
    }

    // ── Carpetas para la pestaña Fondos ──────────────────────────────────
    // Se navega carpeta por carpeta: cada una muestra sus subcarpetas y sus
    // propios fondos, sin mezclar lo de adentro. Raíces: la carpeta de
    // Configuración → Fondo y, con skwd-wall, las de su biblioteca.
    property list<string> skwdFolders: []
    readonly property list<string> roots: {
        const all = [folder];
        for (const f of skwdFolders) if (!all.includes(f)) all.push(f);
        return all;
    }
    // "" = la raíz (las carpetas raíz o, si hay una sola, esa misma).
    property string browseDir: ""
    // Entradas: { path, name, kind: "folder" | "image" | "video" | "scene", count, cover }
    property var entries: []
    property bool browsing: false
    readonly property bool atRoot: browseDir === "" || (roots.length === 1 && browseDir === roots[0])

    FileView {
        path: root.viaSkwd ? `${Quickshell.env("HOME")}/.config/skwd-wall-v2/config.json` : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const home = Quickshell.env("HOME");
                root.skwdFolders = (JSON.parse(text()).library?.folders ?? [])
                    .map(f => f.replace(/^~(?=\/|$)/, home).replace(/\/$/, ""));
            } catch (e) {
                root.skwdFolders = [];
            }
        }
    }

    function kindOf(path: string): string {
        if (imageExt.test(path)) return "image";
        if (animatedSupported && videoExt.test(path)) return "video";
        return "";
    }

    function baseName(path: string): string {
        return path.replace(/\/$/, "").split("/").pop().replace(/\.[^.]+$/, "");
    }

    // Miniatura para la grilla: la de skwd si la tiene; si no, la imagen misma
    // (la grilla la decodifica chica) o un cuadro del video generado acá.
    function thumbFor(path: string): string {
        const s = skwdIndex[path]?.thumb;
        if (s) return s;
        if (videoExt.test(path)) {
            requestThumb(path);
            return `${thumbDir}/${Qt.md5(path)}.jpg`;
        }
        return path;
    }

    function browse(dir: string): void {
        if (dir === "" && roots.length === 1) dir = roots[0];
        browseDir = dir;
        if (dir === "") {
            listRoots();
            return;
        }
        if (dir === "@scenes") {
            entries = skwdScenes.map(p => ({ path: p, name: baseName(p), kind: "scene", count: 0, cover: "" }))
                .sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));
            return;
        }
        browsing = true;
        lister.running = false;
        lister.dir = dir;
        // Un nivel de fondos y, de cada subcarpeta, sus fondos directos (para
        // la cantidad y la tapa). Sin entrar más hondo ni a carpetas ocultas.
        lister.command = ["find", "-L", dir, "-mindepth", "1", "-maxdepth", "2",
            "-name", ".*", "-prune", "-o", "-printf", "%y\t%d\t%p\n"];
        lister.running = true;
    }

    function up(): void {
        if (atRoot) return;
        if (browseDir === "@scenes" || roots.includes(browseDir)) {
            browse("");
            return;
        }
        browse(browseDir.slice(0, browseDir.lastIndexOf("/")));
    }

    // Las raíces como carpetas, con la cantidad y la tapa de sus fondos directos.
    function listRoots(): void {
        browsing = true;
        lister.running = false;
        lister.dir = "";
        lister.command = ["find", "-L", ...roots, "-mindepth", "1", "-maxdepth", "1",
            "-name", ".*", "-prune", "-o", "-type", "f", "-printf", "f\t2\t%p\n"];
        lister.running = true;
    }

    Process {
        id: lister

        property string dir: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // Respuesta de una carpeta que ya no es la abierta: descartar.
                if (lister.dir !== root.browseDir) return;
                const folders = {};
                const files = [];
                if (lister.dir === "")
                    for (const r of root.roots) folders[r] = { path: r, name: root.baseName(r), kind: "folder", count: 0, cover: "" };
                for (const line of text.split("\n")) {
                    const [type, depth, path] = line.split("\t");
                    if (!path) continue;
                    if (depth === "1") {
                        if (type === "d") folders[path] = { path, name: root.baseName(path), kind: "folder", count: 0, cover: "" };
                        else if (type === "f" && root.kindOf(path)) files.push({ path, name: root.baseName(path), kind: root.kindOf(path), count: 0, cover: "" });
                    } else if (type === "f" && root.kindOf(path)) {
                        const parent = folders[path.slice(0, path.lastIndexOf("/"))];
                        if (!parent) continue;
                        parent.count++;
                        if (!parent.cover || path < parent.coverPath) {
                            parent.coverPath = path;
                            parent.cover = root.thumbFor(path);
                        }
                    }
                }
                const byName = (a, b) => a.name.localeCompare(b.name, undefined, { numeric: true });
                const list = lister.dir === "" ? Object.values(folders) : Object.values(folders).sort(byName);
                if (lister.dir === "" && root.skwdScenes.length > 0)
                    list.push({ path: "@scenes", name: "Escenas de Wallpaper Engine", kind: "folder",
                        count: root.skwdScenes.length, cover: root.skwdIndex[root.skwdScenes[0]].thumb });
                root.entries = list.concat(files.sort(byName));
                root.browsing = false;
            }
        }
    }

    // Miniaturas de videos propios: un cuadro a 480 px con ffmpeg, una vez.
    property var thumbQueue: []
    property var thumbsDone: ({})
    property var thumbsReady: ({})
    // Cambia al terminar cada miniatura, para que las vistas recarguen.
    property int thumbsVersion: 0

    function requestThumb(path: string): void {
        if (thumbsDone[path] || thumbQueue.includes(path)) return;
        thumbQueue.push(path);
        if (!thumbMaker.running) nextThumb();
    }

    function nextThumb(): void {
        const path = thumbQueue.shift();
        if (!path) return;
        thumbsDone[path] = true;
        thumbMaker.path = path;
        thumbMaker.target = `${thumbDir}/${Qt.md5(path)}.jpg`;
        thumbMaker.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && { [ -s "$2" ] || ffmpeg -nostdin -loglevel error -ss 1 -i "$1" -frames:v 1 -vf scale=480:-2 -y "$2"; }',
            "sh", path, thumbMaker.target];
        thumbMaker.running = true;
    }

    Process {
        id: thumbMaker
        property string path: ""
        property string target: ""
        onExited: {
            root.thumbsReady[path] = true;
            root.thumbsVersion++;
            if (path === root.currentPath && !root.source) root.resolve();
            Qt.callLater(root.nextThumb);
        }
    }

    // ── Rendimiento de los fondos animados ───────────────────────────────
    // En modo gaming (o pantalla completa de un juego) se congelan: sin
    // decodificar video ni componer cuadros nuevos detrás del juego.
    readonly property bool animatedPaused: Theme.gaming
    property bool skwdPausedByUs: false

    onAnimatedPausedChanged: {
        if (!viaSkwd) return;
        if (animatedPaused) {
            skwdPauser.command = [helm, "pause"];
            skwdPausedByUs = true;
        } else if (skwdPausedByUs) {
            skwdPauser.command = [helm, "resume"];
            skwdPausedByUs = false;
        } else return;
        skwdPauser.running = true;
    }

    Process { id: skwdPauser }
}
