pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado de ventanas y escritorios de KWin, recibido a través de
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

    // Hay una captura de pantalla en curso: los popups de la barra se ocultan
    // al instante para no tapar el selector de Spectacle ni salir en la foto.
    property bool screenshotOverlay: false
    property bool screenshotPending: false
    readonly property bool screenshotActive: screenshotOverlay || screenshotPending

    // Captura "limpia": oculta los popups, espera a que se borren de la
    // pantalla y recién entonces abre Spectacle. Pensado para asignarle la
    // tecla Impr Pant (ver README):
    //   qs ipc -p <ruta>/shell.qml call screenshot region
    // Modos: region, fullscreen, window (ventana activa), monitor.
    IpcHandler {
        target: "screenshot"

        function region(): void { root.screenshot("-r"); }
        function fullscreen(): void { root.screenshot("-f"); }
        function window(): void { root.screenshot("-a"); }
        function monitor(): void { root.screenshot("-m"); }
    }

    property string pendingMode: ""
    function screenshot(mode: string): void {
        pendingMode = mode;
        screenshotPending = true;
        launchShot.restart();
    }

    Timer {
        id: launchShot
        // Un par de cuadros para que el compositor ya no muestre los popups.
        interval: 120
        onTriggered: {
            Quickshell.execDetached(["spectacle", root.pendingMode]);
            pendingClear.restart();
        }
    }

    // Respaldo por si el puente no ve la ventana de Spectacle (o en modos sin
    // selector, donde no aparece ninguna).
    Timer {
        id: pendingClear
        interval: 2500
        onTriggered: root.screenshotPending = false
    }

    readonly property int currentDesktopIndex: desktops.findIndex(d => d.id === currentDesktop)

    function windowsOn(desktopId: string): list<var> {
        return windows.filter(w => w.onAllDesktops || w.desktops.includes(desktopId));
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
        if (screenshotOverlay) {
            pendingClear.stop();
            screenshotPending = false;
        }
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
