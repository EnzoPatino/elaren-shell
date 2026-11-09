pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Espectro de audio en tiempo real con cava (si está instalado).
//
// Solo corre mientras alguien lo pide (`users` > 0), así no gasta CPU con
// los paneles cerrados. Sin cava, `available` es false y la interfaz usa el
// nivel de pico de PipeWire como respaldo.
Singleton {
    id: root

    readonly property int barCount: 48
    property bool available: false
    property list<real> bars: []

    // Contador de interesados: cada vista hace acquire() al mostrarse y
    // release() al ocultarse.
    property int users: 0
    function acquire(): void { users++; }
    function release(): void { users = Math.max(0, users - 1); }

    readonly property string config: `
[general]
bars = ${barCount}
framerate = 60
autosens = 1

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10

[smoothing]
noise_reduction = 0.7
`

    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        onExited: code => root.available = code === 0
    }

    Process {
        id: cava

        running: root.available && root.users > 0
        command: ["sh", "-c",
            'conf="${XDG_RUNTIME_DIR:-/tmp}/elaren-cava.conf"; printf "%s" "$1" > "$conf"; exec cava -p "$conf"',
            "sh", root.config]

        stdout: SplitParser {
            onRead: line => {
                const values = line.split(";");
                const out = [];
                for (let i = 0; i < root.barCount; i++) out.push((parseInt(values[i]) || 0) / 1000);
                root.bars = out;
            }
        }

        onRunningChanged: if (!running) root.bars = []
    }
}
