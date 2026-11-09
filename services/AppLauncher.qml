pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado y lógica del lanzador de aplicaciones: catálogo agrupado en secciones,
// búsqueda con ranking y registro de las apps más usadas.
//
// Abrir/cerrar desde fuera (p. ej. un atajo de teclado):
//   qs ipc -p <ruta>/shell.qml call launcher toggle
Singleton {
    id: root

    property bool open: false

    function toggle(): void { open = !open; }
    function show(): void { open = true; }
    function hide(): void { open = false; }

    IpcHandler {
        target: "launcher"

        // (no se llaman show/hide porque chocan con subcomandos de `qs ipc`)
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
    }

    // ── Secciones ─────────────────────────────────────────────────────────
    // `categories`: categorías freedesktop que caen en la sección (la primera
    // sección que coincide gana, por eso Juegos va antes que el resto).
    readonly property list<var> sectionDefs: [
        { id: "all", name: "Todas", icon: "apps" },
        { id: "frequent", name: "Frecuentes", icon: "history" },
        { id: "games", name: "Juegos", icon: "sports_esports", categories: ["Game"] },
        { id: "internet", name: "Internet", icon: "language", categories: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { id: "media", name: "Multimedia", icon: "play_circle", categories: ["AudioVideo", "Audio", "Video", "Player", "Music"] },
        { id: "graphics", name: "Gráficos", icon: "palette", categories: ["Graphics", "Photography", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics"] },
        { id: "dev", name: "Desarrollo", icon: "code", categories: ["Development", "IDE", "TextEditor"] },
        { id: "office", name: "Oficina", icon: "description", categories: ["Office", "Education", "Science", "Documentation"] },
        { id: "system", name: "Sistema", icon: "tune", categories: ["System", "Settings", "TerminalEmulator", "Monitor", "PackageManager"] },
        { id: "utilities", name: "Utilidades", icon: "construction", categories: ["Utility", "Accessories", "FileManager", "Archiving", "Viewer"] },
        { id: "other", name: "Otras", icon: "category" }
    ]

    readonly property list<var> apps: [...DesktopEntries.applications.values]
        .filter(app => !app.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    function sectionOf(app: var): string {
        const cats = app.categories ?? [];
        for (const section of sectionDefs) {
            if (section.categories && section.categories.some(c => cats.includes(c))) return section.id;
        }
        return "other";
    }

    // Mapa id de sección → apps, recalculado solo cuando cambia el catálogo.
    readonly property var bySection: {
        const map = {};
        for (const section of sectionDefs) map[section.id] = [];
        map.all = apps;
        for (const app of apps) map[sectionOf(app)].push(app);
        return map;
    }

    readonly property list<var> frequent: apps
        .filter(app => launchCount(app) > 0)
        .sort((a, b) => launchCount(b) - launchCount(a))
        .slice(0, 18)

    // Secciones con contenido (para la barra lateral).
    readonly property list<var> sections: sectionDefs
        .map(s => ({ id: s.id, name: s.name, icon: s.icon, count: appsIn(s.id).length }))
        .filter(s => s.id === "all" || s.count > 0)

    function appsIn(sectionId: string): list<var> {
        if (sectionId === "frequent") return frequent;
        return bySection[sectionId] ?? [];
    }

    // ── Búsqueda ──────────────────────────────────────────────────────────
    function normalize(text: string): string {
        return (text ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    // ¿Las letras de `query` aparecen en orden dentro de `text`? (p. ej. "ffx" → "Firefox")
    function isSubsequence(query: string, text: string): bool {
        let i = 0;
        for (const ch of text) {
            if (ch === query[i]) i++;
            if (i === query.length) return true;
        }
        return false;
    }

    function score(app: var, query: string): real {
        const name = normalize(app.name);
        let best = 0;
        if (name === query) best = 100;
        else if (name.startsWith(query)) best = 80;
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(query))) best = 65;
        else if (name.includes(query)) best = 50;
        else {
            const extra = [app.genericName, app.comment, app.id, ...(app.keywords ?? [])].map(normalize);
            if (extra.some(t => t.split(/[\s\-_.;,]+/).some(w => w.startsWith(query)))) best = 35;
            else if (extra.some(t => t.includes(query))) best = 25;
            else if (query.length >= 2 && isSubsequence(query, name)) best = 15;
        }
        // Las apps que más usás suben un poco en el ranking.
        return best > 0 ? best + Math.min(10, launchCount(app)) : 0;
    }

    function search(query: string): list<var> {
        const q = normalize(query.trim());
        if (!q) return apps;
        return apps
            .map(app => ({ app, score: score(app, q) }))
            .filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name))
            .map(r => r.app);
    }

    // ── Lanzar y recordar ─────────────────────────────────────────────────
    function launchCount(app: var): int {
        return store.launches[app.id] ?? 0;
    }

    function launch(app: var): void {
        if (!app) return;
        const counts = Object.assign({}, store.launches);
        counts[app.id] = (counts[app.id] ?? 0) + 1;
        store.launches = counts;
        app.execute();
        hide();
    }

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/elaren`

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: storeFile.path = `${root.stateDir}/launcher.json`
    }

    // Se asigna la ruta recién cuando existe la carpeta; si el archivo no
    // existe todavía, se crea vacío.
    FileView {
        id: storeFile
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: store
            property var launches: ({})
        }
    }
}
