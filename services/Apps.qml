pragma Singleton
import QtQuick
import Quickshell
import "../config"

// Modelo del dock: apps fijadas + apps con ventanas abiertas, agrupadas.
// `dockIds` es una lista de strings estable (el appId de cada icono), así los
// delegados no se recrean cuando solo cambia, p. ej., el título de una ventana.
Singleton {
    id: root

    readonly property string separator: "__separator__"

    readonly property list<string> dockIds: {
        const ids = [...Config.pinnedApps];
        const known = new Set(ids.map(id => key(id)));
        const extra = [];
        for (const w of KWin.windows) {
            const k = key(w.appId);
            if (!known.has(k) && !known.has(key(entryKey(w.appId)))) {
                known.add(k);
                extra.push(w.appId);
            }
        }
        return extra.length > 0 ? [...ids, separator, ...extra] : ids;
    }

    function key(id: string): string {
        return (id ?? "").toLowerCase().replace(/\.desktop$/, "");
    }

    function entry(appId: string): DesktopEntry {
        return DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId);
    }

    // Id del .desktop que corresponde a un appId de ventana (si se encuentra).
    function entryKey(appId: string): string {
        return entry(appId)?.id ?? appId;
    }

    function matches(appId: string, window: var): bool {
        const k = key(appId);
        if (key(window.appId) === k || key(window.resourceClass) === k) return true;
        const e = entry(appId);
        return !!e && (key(e.startupClass) === key(window.resourceClass) || key(e.id) === key(window.appId));
    }

    function windowsFor(appId: string): list<var> {
        return KWin.windows.filter(w => matches(appId, w));
    }

    function name(appId: string): string {
        return entry(appId)?.name || appId;
    }

    function icon(appId: string): string {
        return Quickshell.iconPath(entry(appId)?.icon || appId, "application-x-executable");
    }

    function isPinned(appId: string): bool {
        return Config.pinnedApps.some(id => key(id) === key(appId));
    }

    function launch(appId: string): void {
        const e = entry(appId);
        if (e) e.execute();
        else Quickshell.execDetached(["gtk-launch", appId]);
    }

    // Clic en un icono: abre la app, alterna su ventana o rota entre varias.
    function activate(appId: string): bool {
        const windows = windowsFor(appId);
        if (windows.length === 0) {
            launch(appId);
            return true; // se lanzó
        }
        if (windows.length === 1) {
            KWin.toggle(windows[0].id);
            return false;
        }
        const current = windows.findIndex(w => w.id === KWin.activeWindow);
        KWin.activate(windows[(current + 1) % windows.length].id);
        return false;
    }
}
