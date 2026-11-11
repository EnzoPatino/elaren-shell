pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Bloquear, suspender, cerrar sesión, reiniciar y apagar, con una animación
// a pantalla completa ANTES de ejecutar la acción (ver modules/power).
//
// - Mientras dura la animación se puede cancelar (Esc o clic).
// - Al desbloquear la sesión (venga de donde venga el bloqueo: Elaren,
//   Meta+L, inactividad…) se reproduce una animación de bienvenida.
//
// Para que los atajos de KDE también tengan animación, asignales p. ej.:
//   qs ipc -p <ruta>/shell.qml call power lock
//   qs ipc -p <ruta>/shell.qml call power poweroff
Singleton {
    id: root

    // Acción en curso: "" | "lock" | "suspend" | "logout" | "reboot" | "poweroff"
    property string action: ""
    // Ya se ejecutó el comando (no se puede cancelar)
    property bool committed: false
    // Animación de bienvenida al desbloquear
    property bool welcome: false
    // La sesión está bloqueada ahora mismo
    property bool locked: false

    readonly property bool busy: action !== ""

    readonly property var commands: ({
        lock: ["loginctl", "lock-session"],
        suspend: ["systemctl", "suspend"],
        logout: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"],
        reboot: ["systemctl", "reboot"],
        poweroff: ["systemctl", "poweroff"]
    })

    // Duración de la animación previa (ms, sin escalar)
    readonly property var durations: ({
        lock: 1100,
        suspend: 1300,
        logout: 1700,
        reboot: 1700,
        poweroff: 1900
    })

    // Ensayo: reproduce la animación sin ejecutar nada.
    property bool dryRun: false

    function run(name: string): void {
        start(name, false);
    }

    function preview(name: string): void {
        start(name, true);
    }

    function start(name: string, dry: bool): void {
        if (!commands[name] || busy) return;
        dryRun = dry;
        committed = false;
        welcome = false;
        action = name;
        // Sin animaciones, directo.
        execTimer.interval = Math.max(1, durations[name] * Math.min(1, Theme.anim.scale));
        execTimer.restart();
    }

    function cancel(): void {
        if (!busy || committed) return;
        execTimer.stop();
        action = "";
    }

    Timer {
        id: execTimer
        onTriggered: {
            root.committed = true;
            if (root.dryRun) {
                // Ensayo: un instante en el estado final y se retira (con la
                // bienvenida si era bloquear o suspender).
                fallback.interval = 700;
                fallback.restart();
                return;
            }
            Quickshell.execDetached(root.commands[root.action]);
            // Bloquear/suspender: el telón queda negro debajo del bloqueador
            // y al volver se abre con la bienvenida. Apagar/reiniciar/salir:
            // si en unos segundos no pasó nada (p. ej. se canceló un diálogo
            // de polkit), se retira solo.
            fallback.interval = root.action === "lock" || root.action === "suspend" ? 4000 : 9000;
            fallback.restart();
        }
    }

    // Respaldo: nunca dejar la pantalla tapada si la acción no ocurrió.
    Timer {
        id: fallback
        onTriggered: {
            if (root.action === "lock" && root.locked) return; // la abre el desbloqueo
            if (root.dryRun) {
                root.finish(root.action === "lock" || root.action === "suspend");
                return;
            }
            if (root.action === "suspend") {
                root.finish(true);
                return;
            }
            root.finish(false);
        }
    }

    // Termina la acción; con `greet`, abre el telón con la bienvenida.
    function finish(greet: bool): void {
        fallback.stop();
        execTimer.stop();
        committed = false;
        action = "";
        if (greet) {
            welcome = true;
            welcomeTimer.restart();
        }
    }

    Timer {
        id: welcomeTimer
        interval: 2600
        onTriggered: root.welcome = false
    }

    // ── Estado del bloqueo de KDE ─────────────────────────────────────────
    // Consulta directa (al arrancar y, mientras está bloqueada, cada pocos
    // segundos: si se perdiera la señal de desbloqueo, el telón negro que
    // queda debajo del bloqueador no puede quedarse puesto).
    Process {
        id: lockQuery
        running: true
        command: ["busctl", "--user", "call", "org.freedesktop.ScreenSaver", "/ScreenSaver",
            "org.freedesktop.ScreenSaver", "GetActive"]
        stdout: SplitParser {
            onRead: line => {
                const nowLocked = line.trim() === "b true";
                if (root.locked && !nowLocked) {
                    root.locked = false;
                    root.finish(Theme.anim.scale > 0);
                } else {
                    root.locked = nowLocked;
                }
            }
        }
    }
    Timer {
        interval: 2500
        repeat: true
        running: root.locked
        onTriggered: lockQuery.running = true
    }

    Process {
        id: monitor
        running: true
        command: ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.ScreenSaver", "--object-path", "/ScreenSaver"]
        stdout: SplitParser {
            onRead: line => {
                const match = line.match(/ActiveChanged \((true|false),\)/);
                if (!match) return;
                const nowLocked = match[1] === "true";
                if (nowLocked === root.locked) return;
                root.locked = nowLocked;
                if (!nowLocked) {
                    // Desbloqueo: bienvenida (también tras Meta+L o inactividad)
                    root.finish(Theme.anim.scale > 0);
                }
            }
        }
        onExited: monitorRestart.start()
    }
    Timer {
        id: monitorRestart
        interval: 5000
        onTriggered: monitor.running = true
    }

    IpcHandler {
        target: "power"

        function lock(): void { root.run("lock"); }
        function suspend(): void { root.run("suspend"); }
        function logout(): void { root.run("logout"); }
        function reboot(): void { root.run("reboot"); }
        function poweroff(): void { root.run("poweroff"); }
        function cancel(): void { root.cancel(); }
        // Ensayo de la animación, sin ejecutar la acción:
        //   qs ipc -p <ruta>/shell.qml call power preview poweroff
        function preview(name: string): void { root.preview(name); }
        // Solo la animación de bienvenida (para probarla)
        function greet(): void { root.finish(true); }
    }
}
