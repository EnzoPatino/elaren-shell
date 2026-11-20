pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brillo de la pantalla del portátil, sin root ni brightnessctl:
//   - Plasma: PowerDevil (el servicio de energía de Plasma). Escucha la señal
//     brightnessChanged, así también se entera de los cambios por teclado.
//   - Sin PowerDevil (Hyprland): lee /sys/class/backlight y escribe con
//     SetBrightness de logind, que la sesión activa puede usar sin permisos
//     extra. sysfs no avisa los cambios, así que se relee cada segundo.
//
// Teclas de brillo en Hyprland (ver README):
//   qs ipc -p <ruta>/shell.qml call brightness up|down
Singleton {
    id: root

    readonly property string service: "org.kde.Solid.PowerManagement"
    readonly property string path: "/org/kde/Solid/PowerManagement/Actions/BrightnessControl"
    readonly property string iface: "org.kde.Solid.PowerManagement.Actions.BrightnessControl"

    // "powerdevil", "sysfs" o "" mientras se detecta (o si no hay pantalla
    // con brillo regulable).
    property string backend: ""
    readonly property bool available: backend !== "" && maximum > 0
    property int raw: 0
    property int maximum: 0
    readonly property real value: maximum > 0 ? raw / maximum : 0

    // Solo sysfs: dispositivo y sesión de logind.
    property string device: ""
    property string session: ""

    readonly property string icon: value >= 0.66 ? "brightness_high"
        : value >= 0.33 ? "brightness_medium" : "brightness_low"

    function call(method: string, args: list<string>): list<string> {
        return ["gdbus", "call", "--session", "--dest", service, "--object-path", path,
                "--method", `${iface}.${method}`, ...args];
    }

    function setValue(fraction: real): void {
        if (!available) return;
        // Nunca a 0: una pantalla negra sin forma fácil de volver no es un "chiche".
        const target = Math.round(Math.max(0.01, Math.min(1, fraction)) * maximum);
        raw = target;
        if (backend === "powerdevil") {
            Quickshell.execDetached(call("setBrightnessSilent", [`${target}`]));
        } else {
            // Que la relectura no pise el valor mientras logind lo aplica.
            settle.restart();
            Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1",
                session, "org.freedesktop.login1.Session", "SetBrightness",
                "ssu", "backlight", device, `${target}`]);
        }
    }

    function change(delta: real): void {
        setValue(value + delta);
    }

    // Lectura inicial: "(10000,)\n(10000,)" → actual y máximo.
    Process {
        id: reader
        running: true
        command: ["sh", "-c", 'gdbus call --session --dest "$1" --object-path "$2" --method "$3.brightness" '
            + '&& gdbus call --session --dest "$1" --object-path "$2" --method "$3.brightnessMax"',
            "sh", root.service, root.path, root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                const nums = (text.match(/-?\d+/g) ?? []).map(Number);
                if (nums.length >= 2 && nums[1] > 0) {
                    root.raw = nums[0];
                    root.maximum = nums[1];
                    root.backend = "powerdevil";
                }
            }
        }
        onExited: code => { if (code !== 0) sysfsProbe.running = true; }
    }

    Process {
        running: root.backend === "powerdevil"
        command: ["gdbus", "monitor", "--session", "--dest", root.service, "--object-path", root.path]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/brightnessChanged \(\D*(\d+)/);
                if (m) root.raw = parseInt(m[1]);
            }
        }
    }

    // ── Respaldo sin PowerDevil ──────────────────────────────────────────
    // Imprime "<dispositivo> <máximo> <ruta de la sesión>". Elige el
    // dispositivo con más pasos (el de la GPU suele tener más precisión que
    // el genérico de ACPI). La sesión se busca como en logind-monitor.sh:
    // "auto" falla si Quickshell corre desde una unidad de systemd.
    Process {
        id: sysfsProbe
        command: ["sh", "-c", `
            best= ; bestmax=0
            for d in /sys/class/backlight/*; do
                [ -r "$d/max_brightness" ] || continue
                m=$(cat "$d/max_brightness")
                [ "$m" -gt "$bestmax" ] && { best=\${d##*/}; bestmax=$m; }
            done
            [ -n "$best" ] || exit 1
            get() { busctl --system call org.freedesktop.login1 /org/freedesktop/login1 \\
                org.freedesktop.login1.Manager "$@" 2>/dev/null | awk '{ print $2 }' | tr -d '"'; }
            s=$(get GetSession s auto)
            [ -n "$s" ] || [ -z "$XDG_SESSION_ID" ] || s=$(get GetSession s "$XDG_SESSION_ID")
            [ -n "$s" ] || s=$(get GetSessionByPID u $$)
            [ -n "$s" ] || exit 1
            echo "$best $bestmax $s"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [device, max, session] = text.trim().split(/\s+/);
                if (!device || !(Number(max) > 0) || !session) return;
                root.device = device;
                root.session = session;
                root.maximum = Number(max);
                root.backend = "sysfs";
            }
        }
        onExited: code => {
            if (code !== 0) console.info("brillo: no hay pantalla con brillo regulable");
        }
    }

    FileView {
        id: sysfsValue
        path: root.backend === "sysfs" ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: {
            const n = parseInt(text());
            if (!isNaN(n) && !settle.running) root.raw = n;
        }
    }

    Timer {
        running: root.backend === "sysfs"
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!settle.running) sysfsValue.reload()
    }

    Timer { id: settle; interval: 600 }

    IpcHandler {
        target: "brightness"

        function up(): void { root.change(0.05); }
        function down(): void { root.change(-0.05); }
        function set(percent: int): void { root.setValue(percent / 100); }
        function get(): int { return Math.round(root.value * 100); }
    }
}
