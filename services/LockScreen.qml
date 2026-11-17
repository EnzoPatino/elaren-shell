pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../theme"

// Pantalla de bloqueo propia (lockscreen/org.elaren.lockscreen).
//
// La dibuja kscreenlocker, no Quickshell: KWin no ofrece ext-session-lock y
// un bloqueo hecho desde la shell se podría saltear matando el proceso. Este
// servicio la instala/desinstala con scripts/lockscreen.sh y le copia el
// acento, el avatar y las opciones de Configuración → Bloqueo a
// kscreenlockerrc, que el greeter lee cada vez que se bloquea.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/lockscreen.sh")

    // "unknown" | "off" | "pending" (instalada, falta reiniciar sesión) | "active"
    // | "blocked" (instalada, pero plasmashellrc fija ShellPackage y la anula)
    // | "unsupported" (instalada, pero KWin no corre como unidad de systemd)
    property string state: "unknown"
    readonly property bool installed: ["pending", "active", "blocked", "unsupported"].includes(state)
    property bool busy: false
    // Última salida del script (errores, avisos)
    property string message: ""

    function install(): void {
        run(["install"]);
    }

    function uninstall(): void {
        run(["uninstall"]);
    }

    // Abre la pantalla en modo prueba: no bloquea la sesión, se cierra con
    // la contraseña. Primero termina de escribir las opciones actuales, para
    // que la vista previa no muestre las anteriores.
    property bool testPending: false
    property bool resyncNeeded: false

    function test(): void {
        if (testProc.running) return;
        testPending = true;
        syncTimer.stop();
        // Un sync en curso puede llevar valores viejos: repetirlo al terminar.
        if (syncProc.running) resyncNeeded = true;
        else startSync();
    }

    function refresh(): void {
        statusProc.running = true;
    }

    function run(args: list<string>): void {
        if (busy) return;
        busy = true;
        message = "";
        actionOut = "";
        actionErr = "";
        actionProc.command = [script, ...args];
        actionProc.running = true;
    }

    // Opciones que lee el greeter (ver lockscreen/…/config.xml)
    readonly property var values: ({
        accent: Theme.primary.toString(),
        accentSecondary: Theme.secondary.toString(),
        accentOn: Theme.textOnPrimary.toString(),
        // Respeta ELAREN_ANIM_SCALE, como el resto de la shell.
        animationScale: String(Theme.userAnim.scale),
        avatarShape: Config.barAvatarShape,
        avatarImage: Config.barAvatarSource === "plasma" ? Config.barAvatarImage
            : Config.barAvatarSource === "face" ? Quickshell.env("HOME") + "/.face"
            : "",
        blur: Config.lockscreenBlur ? "true" : "false",
        showMedia: Config.lockscreenShowMedia ? "true" : "false",
        clockSeconds: Config.lockscreenClockSeconds ? "true" : "false"
    })

    function sync(): void {
        if (syncProc.running) syncTimer.restart();
        else startSync();
    }

    function startSync(): void {
        syncProc.command = [script, "sync", ...Object.keys(values).map(k => `${k}=${values[k]}`)];
        syncProc.running = true;
    }

    // Antes de sincronizar se vuelve a leer el estado: puede haberse
    // instalado desde la terminal (scripts/lockscreen.sh install) con la
    // shell abierta, y `installed` habría quedado viejo.
    onValuesChanged: syncTimer.restart()
    onInstalledChanged: if (installed) sync()
    property bool syncAfterStatus: false

    Timer {
        id: syncTimer
        interval: 800
        onTriggered: {
            root.syncAfterStatus = true;
            root.refresh();
        }
    }

    Process {
        id: syncProc
        onExited: {
            if (root.resyncNeeded) {
                root.resyncNeeded = false;
                root.startSync();
            } else if (root.testPending) {
                root.testPending = false;
                root.message = "";
                testProc.running = true;
            }
        }
    }

    Process {
        id: testProc
        command: [root.script, "test"]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.message = text.trim()
        }
    }

    Process {
        id: statusProc
        running: true
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.state = text.trim() || "off";
                if (root.syncAfterStatus) {
                    root.syncAfterStatus = false;
                    if (root.installed) root.sync();
                }
            }
        }
    }

    // La salida normal y los avisos (stderr) se muestran juntos: el aviso de
    // ShellPackage, por ejemplo, sale por stderr junto al "listo".
    property string actionOut: ""
    property string actionErr: ""
    function updateMessage(): void {
        message = [actionOut, actionErr].filter(t => t !== "").join("\n");
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.actionOut = text.trim();
                root.updateMessage();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.actionErr = text.trim();
                root.updateMessage();
            }
        }
        onExited: {
            root.busy = false;
            root.refresh();
        }
    }

    IpcHandler {
        target: "lockscreen"

        function install(): void { root.install(); }
        function uninstall(): void { root.uninstall(); }
        function test(): void { root.test(); }
        function status(): string { return root.state; }
    }
}
