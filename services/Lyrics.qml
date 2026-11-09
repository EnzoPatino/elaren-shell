pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Letra del tema actual (LRCLIB, vía scripts/lyrics.py, con caché local).
//
// Se busca solo cuando alguien la pide (`wanted`), para no hacer consultas
// por cada tema que suena con los paneles cerrados.
Singleton {
    id: root

    property bool wanted: false

    // "idle" | "loading" | "found" | "none"
    property string status: "idle"
    property bool synced: false
    property list<var> lines: []

    readonly property string trackKey: Media.available ? `${Media.title}|${Media.artist}` : ""
    property string loadedKey: ""

    // Posición interpolada: MPRIS publica la posición a saltos; entre medio
    // se avanza con el reloj para que la línea activa cambie a tiempo.
    property real basePosition: 0
    property real baseTime: 0
    property real now: 0
    readonly property real position: Media.playing ? basePosition + (now - baseTime) / 1000 : basePosition

    Connections {
        target: Media
        function onPositionChanged() {
            root.basePosition = Media.position;
            root.baseTime = Date.now();
            root.now = root.baseTime;
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.wanted && root.synced && Media.playing
        onTriggered: root.now = Date.now()
    }

    // Índice de la línea que está sonando (-1 antes de la primera).
    readonly property int currentIndex: {
        if (!synced) return -1;
        let index = -1;
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].time <= position + 0.15) index = i;
            else break;
        }
        return index;
    }

    function load(): void {
        if (!wanted || !trackKey || trackKey === loadedKey) return;
        loadedKey = trackKey;
        status = "loading";
        lines = [];
        synced = false;
        fetcher.command = ["python3", Quickshell.shellPath("scripts/lyrics.py"),
            Media.title, Media.artist, Media.album, String(Math.round(Media.duration))];
        fetcher.running = true;
    }

    onWantedChanged: load()
    onTrackKeyChanged: load()

    Process {
        id: fetcher

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.synced = result.synced;
                    root.lines = result.lines;
                    root.status = result.lines.length > 0 ? "found" : "none";
                } catch (e) {
                    root.status = "none";
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.status = "none";
                root.loadedKey = ""; // reintentar la próxima vez
            }
        }
    }
}
