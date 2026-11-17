pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../theme"

// Modo gaming: mientras está activo, Elaren gasta lo mínimo para dejarle la
// GPU y el compositor al juego (ver docs/propuesta-modo-gaming.md).
//
// - Se descargan el visualizador y los widgets de escritorio.
// - Se apagan el desenfoque de KWin (el vidrio se vuelve más opaco) y las
//   animaciones (Theme.gaming).
// - El dock se oculta (Config.gameModeHideDock) y las métricas del sistema se
//   leen cada 10 s en vez de cada 2.
// - Opcional: la pantalla no se apaga ni se bloquea (Config.gameModeInhibitIdle).
//
// Se prende desde el botón de la barra, por IPC
//   qs ipc -p <ruta>/shell.qml call gamemode toggle
// o solo, mientras un juego use Feral GameMode (`gamemoderun %command%` en
// Steam), si Config.gameModeAuto está activo. El botón siempre gana: si se
// apaga a mano durante un juego, no vuelve a prenderse hasta el próximo.
// El estado es de la sesión: no se guarda.
Singleton {
    id: root

    // Prendido a mano (botón o IPC)
    property bool manual: false
    // Juegos registrados en gamemoded (-1 = no está disponible)
    property int gameCount: -1
    readonly property bool feralAvailable: gameCount >= 0
    // Se apagó a mano con un juego abierto: ignorar el automático hasta que
    // ese juego termine.
    property bool suppressed: false

    readonly property bool autoActive: Config.gameModeAuto && gameCount > 0 && !suppressed
    readonly property bool active: manual || autoActive

    onGameCountChanged: if (gameCount <= 0) suppressed = false

    function enable(): void {
        manual = true;
        suppressed = false;
    }

    function disable(): void {
        manual = false;
        if (Config.gameModeAuto && gameCount > 0) suppressed = true;
    }

    function toggle(): void {
        if (active) disable();
        else enable();
    }

    // Animaciones y vidrio de toda la shell
    Binding {
        target: Theme
        property: "gaming"
        value: root.active
    }

    // ── Feral GameMode (com.feralinteractive.GameMode, bus de sesión) ────
    readonly property bool watchFeral: Config.gameModeAuto

    Process {
        id: feralQuery
        // --auto-start=no: solo preguntar, no levantar gamemoded por D-Bus.
        command: ["busctl", "--user", "--auto-start=no", "get-property", "com.feralinteractive.GameMode",
            "/com/feralinteractive/GameMode", "com.feralinteractive.GameMode", "ClientCount"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/^i (\d+)/);
                if (match) root.gameCount = parseInt(match[1]);
            }
        }
        onExited: code => { if (code !== 0) root.gameCount = -1; }
    }

    Process {
        id: feralMonitor
        command: ["gdbus", "monitor", "--session", "--dest", "com.feralinteractive.GameMode",
            "--object-path", "/com/feralinteractive/GameMode"]
        stdout: SplitParser {
            onRead: line => {
                const match = line.match(/'ClientCount': <(\d+)>/);
                if (match) root.gameCount = parseInt(match[1]);
                // gdbus avisa los cambios de dueño del nombre con estas líneas:
                //   "The name … is owned by :1.N"       → (re)apareció: preguntar
                //   "The name … does not have an owner" → se cerró o se cayó
                else if (line.includes("does not have an owner")) root.gameCount = -1;
                else if (line.includes("is owned by")) feralQuery.running = true;
            }
        }
        // gdbus monitor espera aunque gamemoded no esté, así que si termina
        // enseguida es un error (falta gdbus, el bus lo rechaza…): reintentar
        // unas veces y después dejarlo, en vez de lanzar procesos para
        // siempre. Si llegó a correr un minuto, la falla es nueva.
        onRunningChanged: if (running) root.monitorStarted = Date.now()
        onExited: {
            if (!root.watchFeral) return;
            if (Date.now() - root.monitorStarted > 60000) root.monitorFailures = 0;
            if (++root.monitorFailures >= 5) {
                console.warn("gamemode: gdbus monitor falla; dejo de vigilar Feral GameMode");
                return;
            }
            feralRestart.start();
        }
    }
    property int monitorFailures: 0
    property real monitorStarted: 0

    Timer {
        id: feralRestart
        interval: 5000
        onTriggered: {
            if (!root.watchFeral) return;
            feralQuery.running = true;
            feralMonitor.running = true;
        }
    }

    function updateFeral(): void {
        monitorFailures = 0;
        if (watchFeral) {
            feralQuery.running = true;
            feralMonitor.running = true;
        } else {
            feralRestart.stop();
            feralMonitor.running = false;
            gameCount = -1;
            suppressed = false;
        }
    }

    onWatchFeralChanged: updateFeral()
    Component.onCompleted: updateFeral()

    IpcHandler {
        target: "gamemode"

        function toggle(): void { root.toggle(); }
        function enable(): void { root.enable(); }
        function disable(): void { root.disable(); }
        function status(): string { return root.active ? "on" : "off"; }
    }
}
