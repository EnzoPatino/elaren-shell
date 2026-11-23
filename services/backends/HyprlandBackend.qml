import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../config"

// Ventanas y espacios de trabajo de Hyprland, con la misma forma que los de
// services/KWin.qml. No es un singleton a propósito: services/Compositor.qml
// lo crea solo en Hyprland, así en Plasma no hace falta que Quickshell traiga
// el módulo Quickshell.Hyprland.
//
// Hyprland no tiene "minimizar": se imita mandando la ventana al espacio
// especial `special:minimized`, como hacen otras barras.
Scope {
    id: root

    readonly property string minimizedWorkspace: "special:minimized"

    readonly property bool connected: true

    // Hyprland crea y destruye los espacios a medida que se usan. Para que la
    // barra y el paralaje del fondo no salten, se muestran siempre del 1 al
    // Config.hyprlandWorkspaces, más los que existan por encima de ese
    // número, sin rellenar los huecos (un espacio 99 no agrega 90 vacíos).
    readonly property var existing: {
        const byId = {};
        for (const w of Hyprland.workspaces.values) if (w.id > 0) byId[w.id] = w.name;
        return byId;
    }
    readonly property list<var> desktops: {
        const count = Math.max(1, Config.hyprlandWorkspaces);
        const ids = [];
        for (let id = 1; id <= count; id++) ids.push(id);
        for (const id of Object.keys(existing).map(Number).sort((a, b) => a - b))
            if (id > count) ids.push(id);
        return ids.map(id => ({ id: String(id), name: existing[id] ?? String(id) }));
    }

    readonly property string currentDesktop: String(Hyprland.focusedWorkspace?.id ?? "")
    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? ""
    readonly property string activeWindow: Hyprland.activeToplevel?.address ?? ""

    // Sin el título: cambia muy seguido y va aparte en `captions`, igual que
    // en el backend de KWin, para no recalcular el dock en cada cambio.
    // `fresh` se recalcula con cada evento; `windows` solo se reemplaza si
    // cambió algo de verdad (refreshToplevels toca todas las ventanas).
    readonly property var fresh: Hyprland.toplevels.values
        .filter(t => t.address !== "")
        .map(t => {
            const ipc = t.lastIpcObject ?? {};
            const appId = t.wayland?.appId || ipc.class || "";
            const workspace = t.workspace;
            return {
                id: t.address,
                appId,
                resourceClass: ipc.class || appId,
                minimized: workspace?.name === root.minimizedWorkspace,
                onAllDesktops: ipc.pinned === true,
                desktops: workspace ? [String(workspace.id)] : []
            };
        })
    property list<var> windows: []
    property string lastWindows: ""
    onFreshChanged: updateWindows()
    function updateWindows(): void {
        const json = JSON.stringify(fresh);
        if (json === lastWindows) return;
        lastWindows = json;
        windows = fresh;
    }

    readonly property var captions: {
        const titles = {};
        for (const t of Hyprland.toplevels.values) titles[t.address] = t.title;
        return titles;
    }

    // Hyprland no avisa cuándo hay un selector de captura en pantalla: los
    // popups se ocultan mientras corre scripts/screenshot.sh.
    readonly property bool screenshotOverlay: false
    // Terminó scripts/screenshot.sh (bien, cancelada o con error).
    signal screenshotSettled()

    function target(id: string): string {
        return "address:" + (id.startsWith("0x") ? id : "0x" + id);
    }

    function find(id: string): var {
        return windows.find(w => w.id === id) ?? null;
    }

    function activate(id: string): void {
        const w = find(id);
        // Volver del espacio de "minimizadas" al espacio normal del monitor
        // enfocado (aunque haya uno especial abierto encima) antes de enfocarla.
        if (w?.minimized) {
            const workspace = Hyprland.focusedMonitor?.activeWorkspace?.id ?? Number(currentDesktop);
            Hyprland.dispatch(`movetoworkspace ${workspace > 0 ? workspace : 1},${target(id)}`);
        }
        Hyprland.dispatch(`focuswindow ${target(id)}`);
    }

    // Una ventana ya minimizada puede seguir figurando como activa (si no
    // quedó otra para enfocar): en ese caso se restaura.
    function toggle(id: string): void {
        const w = find(id);
        if (id === activeWindow && !w?.minimized)
            Hyprland.dispatch(`movetoworkspacesilent ${minimizedWorkspace},${target(id)}`);
        else activate(id);
    }

    function close(id: string): void {
        Hyprland.dispatch(`closewindow ${target(id)}`);
    }

    function switchDesktop(id: string): void {
        Hyprland.dispatch(`workspace ${id}`);
    }

    function stepDesktop(step: int): void {
        const index = desktops.findIndex(d => d.id === currentDesktop);
        // Fuera de la lista (p. ej. un espacio especial): ir al primero o al último.
        const next = index < 0 ? (step > 0 ? 0 : desktops.length - 1)
            : (index + step + desktops.length) % desktops.length;
        switchDesktop(desktops[next].id);
    }

    // Modos: region, fullscreen, window, monitor (ver scripts/screenshot.sh).
    function screenshot(mode: string): void {
        if (shot.running) return;
        shot.command = [Quickshell.shellPath("scripts/screenshot.sh"), mode];
        shot.running = true;
    }

    Process {
        id: shot
        stderr: SplitParser {
            onRead: data => console.warn("screenshot:", data)
        }
        onExited: root.screenshotSettled()
    }

    // `class` y `pinned` vienen de lastIpcObject, que se llena al refrescar.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (["openwindow", "pin"].includes(event.name)) Hyprland.refreshToplevels();
            // Algunas apps definen su clase después de abrir la ventana: mientras
            // haya alguna sin appId, volver a preguntar al cambiar el foco.
            else if (event.name === "activewindowv2" && root.windows.some(w => w.appId === ""))
                Hyprland.refreshToplevels();
        }
    }

    Component.onCompleted: {
        // onFreshChanged no corre con el primer valor: copiar el actual.
        updateWindows();
        Hyprland.refreshToplevels();
    }
}
