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

    function apply(line: string): void {
        let state;
        try {
            state = JSON.parse(line);
        } catch (e) {
            console.warn("kwin-bridge: JSON inválido", e);
            return;
        }
        desktops = state.desktops ?? [];
        currentDesktop = state.currentDesktop ?? "";
        activeWindow = state.active ?? "";
        windows = state.windows ?? [];
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
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: bridge.running = true
    }
}
