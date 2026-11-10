pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Conexión de red activa (NetworkManager vía nmcli). No hace sondeo continuo:
// `nmcli monitor` avisa de los cambios y solo entonces se vuelve a leer.
// La intensidad del wifi se refresca cada tanto porque no genera eventos.
Singleton {
    id: root

    property bool available: false
    // "wifi", "ethernet" o "" (sin conexión)
    property string type: ""
    property string name: ""
    property int signal: 0 // 0..100, solo wifi

    readonly property bool connected: type !== ""

    readonly property string icon: {
        if (!available) return "signal_wifi_bad";
        if (type === "ethernet") return "lan";
        if (type !== "wifi") return "wifi_off";
        if (signal >= 75) return "network_wifi";
        if (signal >= 50) return "network_wifi_3_bar";
        if (signal >= 25) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    function openSettings(): void {
        Quickshell.execDetached(["kcmshell6", "kcm_networkmanagement"]);
    }

    function refresh(): void {
        if (!reader.running) reader.running = true;
    }

    Process {
        id: reader
        running: true
        // Primero el dispositivo conectado (wifi/ethernet), luego la señal del wifi activo.
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null; echo '--'; " +
            "nmcli -t -f ACTIVE,SIGNAL device wifi list --rescan no 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [devices, wifi] = text.split("\n--\n");
                let type = "", name = "";
                for (const line of (devices ?? "").split("\n")) {
                    // nmcli -t escapa los ":" del nombre como "\:"
                    const parts = line.replace(/\\:/g, "\u0001").split(":");
                    if (parts.length < 3 || parts[1] !== "connected") continue;
                    if (parts[0] === "wifi" || parts[0] === "ethernet") {
                        type = parts[0];
                        name = parts.slice(2).join(":").replace(/\u0001/g, ":");
                        if (type === "ethernet") break; // el cable tiene prioridad
                    }
                }
                let signal = 0;
                for (const line of (wifi ?? "").split("\n")) {
                    const [active, strength] = line.split(":");
                    if (active === "yes" || active === "sí") signal = parseInt(strength) || 0;
                }
                root.type = type;
                root.name = name;
                root.signal = signal;
                root.available = true;
            }
        }
        onExited: code => { if (code !== 0) root.available = false; }
    }

    // Eventos de NetworkManager; se agrupan para no leer diez veces seguidas.
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 20000
        repeat: true
        running: root.type === "wifi"
        onTriggered: root.refresh()
    }
}
