pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bloqueo de sesión propio, para compositores con ext-session-lock
// (Hyprland). En Plasma no se usa: ahí bloquea kscreenlocker (ver
// services/LockScreen.qml), porque KWin no ofrece ese protocolo.
//
// Este servicio solo guarda el estado y habla con logind; la pantalla y la
// verificación de la contraseña (PAM) están en modules/lock/, que se carga
// solo donde hace falta. Así, si Quickshell no trae el módulo de PAM, Plasma
// no se rompe.
//
// Bloquea:
//   - Power.run("lock") / `qs ipc … call power lock` (con animación)
//   - `loginctl lock-session` (hypridle: en on-timeout y before_sleep_cmd,
//     nunca en lock_cmd, que se dispara con cada Lock y armaría un bucle)
//   - antes de suspender (PrepareForSleep de logind, p. ej. al cerrar la tapa)
//   - al arrancar, si logind dice que la sesión ya estaba bloqueada (la
//     shell se cayó o se relanzó estando bloqueada)
// Desbloquea SOLO la contraseña correcta en la pantalla. La señal Unlock de
// logind (`loginctl unlock-session[s]`) se ignora a propósito, como hace
// hyprlock: si no, cualquier programa del usuario podría saltear la
// contraseña. Para salir si algo se traba, ver README ("Bloqueo en
// Hyprland").
Singleton {
    id: root

    readonly property bool supported: Compositor.hyprland
    // modules/lock/SessionLockScreen.qml está cargado y puede bloquear. Si no
    // lo está, bloquear de verdad no es posible y Power usa loginctl (por si
    // hay otro bloqueador, como hyprlock, escuchando).
    property bool available: false

    // Sobrevive a las recargas de Quickshell: si se perdiera, el
    // WlSessionLock recargado arrancaría en `false` y soltaría el bloqueo.
    readonly property alias locked: persist.locked
    // El compositor confirmó el bloqueo (todas las pantallas tapadas). Lo
    // actualiza modules/lock/SessionLockScreen.qml.
    property bool secure: false
    // El último bloqueo no llegó a confirmarse (p. ej. hyprlock ya tenía el
    // protocolo). Power lo usa para no mostrar la bienvenida.
    property bool failed: false
    // Compartida entre las pantallas: lo escrito en una se ve en todas.
    property string password: ""

    PersistentProperties {
        id: persist
        reloadableId: "elarenSessionLock"
        property bool locked: false
    }

    // Mientras está bloqueada no se recarga la configuración al cambiar un
    // archivo (un `git pull`, el editor…): menos riesgo y nada de parpadeos.
    Binding {
        when: root.supported
        target: Quickshell
        property: "watchFiles"
        value: !root.locked
    }

    function lock(): void {
        if (!available || locked) return;
        password = "";
        failed = false;
        persist.locked = true;
        setLockedHint(true);
    }

    // Solo para modules/lock, tras verificar la contraseña con PAM.
    function unlock(): void {
        if (!locked) return;
        // Si se desbloqueó con la contraseña, la máquina está despierta:
        // aunque se haya perdido PrepareForSleep(false), el inhibidor tiene
        // que volver.
        if (!failed) preparingSleep = false;
        release();
        setLockedHint(false);
    }

    function release(): void {
        persist.locked = false;
        password = "";
    }

    // El compositor no concedió el bloqueo: se levanta todo sin bienvenida,
    // para no dejar un telón negro sin forma de salir. LockedHint vuelve a
    // false (como estaba antes de lock()): si quedara en true, cualquier
    // recarga posterior lo leería al arrancar y bloquearía de la nada.
    function fail(): void {
        if (!locked) return;
        console.warn("sessionlock: el compositor no confirmó el bloqueo");
        // `failed` vale solo durante este desbloqueo (Power lo lee al recibir
        // lockedChanged para no mostrar la bienvenida). Si quedara en true,
        // un cierre de tapa posterior soltaría el inhibidor antes de tiempo.
        failed = true;
        unlock();
        failed = false;
    }

    // logind recuerda si la sesión está bloqueada (lo usan otros programas,
    // p. ej. para no mostrar notificaciones).
    // Usa la misma sesión que encontró scripts/logind-monitor.sh.
    readonly property string hintPath: sessionPath !== "" ? sessionPath : "/org/freedesktop/login1/session/auto"

    function setLockedHint(value: bool): void {
        Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1",
            hintPath, "org.freedesktop.login1.Session",
            "SetLockedHint", "b", value ? "true" : "false"]);
    }

    // ── Estado inicial: ¿la sesión ya estaba bloqueada? ───────────────────
    property bool hintAtStart: false

    // Se usa una sola vez: si la pantalla se volviera a cargar más tarde, no
    // tiene que bloquear de nuevo.
    onAvailableChanged: {
        if (!available || !hintAtStart) return;
        hintAtStart = false;
        lock();
    }

    // Se consulta una vez, cuando el monitor ya encontró la sesión.
    Process {
        id: hintQuery
        command: ["busctl", "--system", "get-property", "org.freedesktop.login1",
            root.hintPath, "org.freedesktop.login1.Session", "LockedHint"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "b true") return;
                if (root.available) root.lock();
                else root.hintAtStart = true;
            }
        }
    }

    // ── Señales de logind: Lock de esta sesión y PrepareForSleep ──────────
    // El script imprime primero "session <ruta>" y después todo lo que
    // emite logind.
    property string sessionPath: ""

    Process {
        id: logind
        running: root.supported
        command: [Quickshell.shellPath("scripts/logind-monitor.sh")]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("session ")) {
                    const first = root.sessionPath === "";
                    root.sessionPath = line.slice(8).trim();
                    if (first) hintQuery.running = true;
                    logindStable.restart();
                } else if (/\.Manager\.PrepareForSleep \(true/.test(line)) {
                    // Primero bloquear, después marcar: así readyToSleep no
                    // suelta el inhibidor antes de pedir el bloqueo.
                    root.lock();
                    root.preparingSleep = true;
                } else if (/\.Manager\.PrepareForSleep \(false/.test(line)) {
                    root.preparingSleep = false;
                } else if (root.sessionPath !== "" && line.startsWith(root.sessionPath + ":")
                        && /\.Session\.Lock \(\)/.test(line)) {
                    root.lock();
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("logind-monitor:", data)
        }
        onExited: {
            logindStable.stop();
            if (!root.supported) return;
            // Si sigue fallando (p. ej. no hay sesión de logind), se rinde
            // en vez de relanzarlo cada 5 s para siempre.
            if (++logindRestart.attempts > 5) {
                console.warn("sessionlock: sin señales de logind; `loginctl lock-session` no va a bloquear");
                return;
            }
            logindRestart.start();
        }
    }

    // ── Antes de dormir ────────────────────────────────────────────────────
    // Mientras está tomado, logind espera (hasta InhibitDelayMaxSec, 5 s por
    // defecto) antes de suspender. Se suelta recién cuando el compositor
    // confirmó el bloqueo, así al abrir la tapa no se ve el escritorio. Si el
    // bloqueo no es posible, se suelta enseguida para no demorar la
    // suspensión. `cat` termina solo cuando Quickshell cierra el proceso.
    property bool preparingSleep: false
    // Listo para dormir: bloqueo confirmado, o no hay bloqueo posible (no
    // está disponible o falló), y entonces no tiene sentido demorar.
    readonly property bool readyToSleep: preparingSleep && (secure || !locked)

    Process {
        running: root.supported && root.available && !root.readyToSleep
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Elaren",
            "--why=Bloquear la sesión antes de suspender", "cat"]
    }

    // El contador de reintentos vuelve a cero recién cuando el monitor
    // aguantó un rato: si gdbus muriera justo después de arrancar, se rinde
    // igual a los 5 intentos.
    Timer {
        id: logindStable
        interval: 30000
        onTriggered: logindRestart.attempts = 0
    }

    Timer {
        id: logindRestart
        property int attempts: 0
        interval: 5000
        onTriggered: logind.running = true
    }
}
