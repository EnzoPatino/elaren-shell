pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../config"

// Espectro de audio en tiempo real con cava (si está instalado).
//
// Solo corre mientras alguna vista lo pide (`users`), así no gasta CPU con
// los paneles cerrados. Sin cava, `available` es false y la interfaz usa el
// nivel de pico de PipeWire como respaldo.
Singleton {
    id: root

    readonly property int barCount: Math.max(8, Math.min(128, Config.visualizerBars))
    property bool available: false
    property list<real> bars: []

    // Quién necesita datos ahora. Cada vista lo declara con un Binding
    // (no con un contador: las recargas en caliente destruyen las vistas
    // viejas después de crear el servicio nuevo y desarmaban la cuenta).
    property bool popupActive: false
    // El visualizador de escritorio solo se muestra con música sonando.
    readonly property bool desktopActive: Config.visualizerEnabled && Media.playing
    readonly property bool users: popupActive || desktopActive

    // ── Espectro para cualquier vista ─────────────────────────────────────
    // Barras reales de cava; sin cava, barras sintetizadas a partir del nivel
    // de pico real de la salida (en silencio quedan en cero).
    readonly property bool realSpectrum: available && bars.length === barCount
    readonly property list<real> spectrum: realSpectrum ? bars : synthetic
    property list<real> synthetic: []
    // Nivel general suavizado (0..1), útil para halos y opacidades.
    property real level: 0

    // Estilo del visualizador de escritorio (ver SpectrumView).
    // Se puede cambiar en caliente: qs ipc -p <ruta>/shell.qml call visualizer cycle
    readonly property list<string> styles: ["bars", "blocks", "wave", "mirror", "line"]
    readonly property string style: styles.includes(Config.visualizerStyle) ? Config.visualizerStyle : "bars"

    IpcHandler {
        target: "visualizer"

        // Se guarda en la configuración (persiste).
        function cycle(): void {
            Config.visualizerStyle = root.styles[(root.styles.indexOf(root.style) + 1) % root.styles.length];
        }
        function setStyle(style: string): void {
            if (root.styles.includes(style)) Config.visualizerStyle = style;
        }
    }

    PwNodePeakMonitor {
        id: peaks
        node: Pipewire.defaultAudioSink
        enabled: root.users
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Espectro suavizado para dibujar (ataque rápido, caída suave) y
    // "tapitas" que caen despacio, como en los visualizadores clásicos.
    property list<real> display: []
    property list<real> caps: []

    function smooth(dt: real): void {
        const target = spectrum;
        const next = [];
        const nextCaps = [];
        for (let i = 0; i < barCount; i++) {
            const t = Math.min(1, (target[i] ?? 0) * Config.visualizerGain);
            const v = display[i] ?? 0;
            const value = v + (t - v) * (t > v ? 0.55 : 0.18);
            next.push(value);
            const cap = caps[i] ?? 0;
            nextCaps.push(value >= cap ? value : Math.max(value, cap - dt * 0.35));
        }
        display = next;
        caps = nextCaps;
    }

    property real clock: 0
    FrameAnimation {
        running: root.users
        onTriggered: {
            root.clock += frameTime;
            root.smooth(frameTime);
            const peak = Math.min(1, peaks.peak * 1.4);
            root.level += (peak - root.level) * (peak > root.level ? 0.45 : 0.07);
            if (root.realSpectrum) return;
            const out = [];
            for (let i = 0; i < root.barCount; i++) {
                // Forma de "montaña" (graves y medios más altos) modulada por
                // ondas de distinta frecuencia para que no se vea estático.
                const x = i / (root.barCount - 1);
                const shape = 0.3 + 0.7 * Math.pow(Math.sin(Math.PI * (0.15 + 0.85 * x)), 1.5);
                // Suma de ondas lentas con fase continua: barras vecinas se
                // parecen (como en un espectro real) y el conjunto "viaja".
                const t = root.clock;
                const wave = 0.55 + 0.45 * (0.5 * Math.sin(t * 2.1 + i * 0.35)
                    + 0.3 * Math.sin(t * 3.7 - i * 0.62)
                    + 0.2 * Math.sin(t * 6.3 + i * 1.1));
                out.push(root.level * shape * wave);
            }
            root.synthetic = out;
        }
    }

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

    // cava lee la configuración al arrancar: si cambia (p. ej. la cantidad de
    // barras), se reinicia.
    onConfigChanged: if (cava.running) {
        cavaPaused = true;
        cavaRestart.restart();
    }
    property bool cavaPaused: false
    Timer {
        id: cavaRestart
        interval: 150
        onTriggered: root.cavaPaused = false
    }

    Process {
        id: cava

        running: root.available && root.users && !root.cavaPaused
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
