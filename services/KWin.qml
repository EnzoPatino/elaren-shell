pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backend de KWin para services/Compositor.qml (los módulos no lo usan
// directo): estado de ventanas y escritorios recibido a través de
// scripts/kwin-bridge.py (KWin no ofrece estos datos por protocolos Wayland
// que Quickshell entienda). Si el puente cae, se reinicia solo.
Singleton {
    id: root

    property bool connected: false
    property list<var> desktops: []
    property string currentDesktop: ""
    property string activeWindow: ""
    property list<var> windows: []
    // id de ventana → título actual (cambia mucho más seguido que `windows`)
    property var captions: ({})

    // Spectacle muestra su selector (lo usa services/Compositor.qml para
    // ocultar los popups durante la captura). `screenshotSettled` se emite en
    // cada estado que lo reporta, aunque el valor no cambie.
    property bool screenshotOverlay: false
    signal screenshotSettled()

    // Modos: region, fullscreen, window (ventana activa), monitor.
    function screenshot(mode: string): void {
        const flags = { region: "-r", fullscreen: "-f", window: "-a", monitor: "-m" };
        Quickshell.execDetached(["spectacle", flags[mode] ?? "-r"]);
    }

    function activate(id: string): void { send({ cmd: "activate", id }); }
    function toggle(id: string): void { send({ cmd: "toggle", id }); }
    function close(id: string): void { send({ cmd: "close", id }); }
    function switchDesktop(id: string): void { send({ cmd: "desktop", id }); }
    function stepDesktop(step: int): void { send({ cmd: "desktopStep", step }); }

    function send(command: var): void {
        if (bridge.running) bridge.write(JSON.stringify(command) + "\n");
    }

    property string lastDesktops: ""
    property string lastWindows: ""
    property string lastCaptions: ""

    function apply(line: string): void {
        let state;
        try {
            state = JSON.parse(line);
        } catch (e) {
            console.warn("kwin-bridge: JSON inválido", e);
            return;
        }
        // KWin manda el estado completo en cada cambio (incluido cada cambio
        // de título: una terminal con un spinner lo hace varias veces por
        // segundo). Reasignar listas idénticas recreaba los delegados de los
        // escritorios y recalculaba el dock entero, así que solo se toca lo
        // que cambió de verdad.
        const desktopsJson = JSON.stringify(state.desktops ?? []);
        if (desktopsJson !== lastDesktops) {
            lastDesktops = desktopsJson;
            desktops = state.desktops ?? [];
        }
        // Los títulos van aparte (`captions`): así `windows`, del que dependen
        // el dock y los escritorios, solo cambia si se abre, cierra, minimiza
        // o mueve una ventana.
        const list = state.windows ?? [];
        const titles = {};
        for (const w of list) titles[w.id] = w.caption ?? "";
        const windowsJson = JSON.stringify(list.map(w => [w.id, w.appId, w.resourceClass, w.minimized, w.onAllDesktops, w.desktops]));
        if (windowsJson !== lastWindows) {
            lastWindows = windowsJson;
            windows = list;
        }
        const captionsJson = JSON.stringify(titles);
        if (captionsJson !== lastCaptions) {
            lastCaptions = captionsJson;
            captions = titles;
        }
        currentDesktop = state.currentDesktop ?? "";
        activeWindow = state.active ?? "";
        screenshotOverlay = state.screenshot ?? false;
        if (screenshotOverlay) screenshotSettled();
        connected = true;
    }

    Process {
        id: bridge

        command: ["python3", Quickshell.shellPath("scripts/kwin-bridge.py")]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => root.apply(data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("kwin-bridge:", data)
        }

        onExited: {
            root.connected = false;
            root.lastDesktops = "";
            root.lastWindows = "";
            root.lastCaptions = "";
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: bridge.running = true
    }
}
