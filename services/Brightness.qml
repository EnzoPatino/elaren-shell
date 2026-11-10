pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brillo de la pantalla del portátil a través de PowerDevil (el servicio de
// energía de Plasma): no hace falta root ni brightnessctl. Escucha la señal
// brightnessChanged, así también se entera de los cambios por teclado.
Singleton {
    id: root

    readonly property string service: "org.kde.Solid.PowerManagement"
    readonly property string path: "/org/kde/Solid/PowerManagement/Actions/BrightnessControl"
    readonly property string iface: "org.kde.Solid.PowerManagement.Actions.BrightnessControl"

    property bool available: false
    property int raw: 0
    property int maximum: 0
    readonly property real value: maximum > 0 ? raw / maximum : 0

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
        Quickshell.execDetached(call("setBrightnessSilent", [`${target}`]));
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
                    root.available = true;
                }
            }
        }
    }

    Process {
        running: root.available
        command: ["gdbus", "monitor", "--session", "--dest", root.service, "--object-path", root.path]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/brightnessChanged \(\D*(\d+)/);
                if (m) root.raw = parseInt(m[1]);
            }
        }
    }
}
