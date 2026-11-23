pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Letra del tema actual (LRCLIB, vía scripts/lyrics.py, con caché local).
//
// Se busca solo cuando alguien la pide, para no hacer consultas por cada
// tema que suena con los paneles cerrados: la pestaña Letra de la isla
// (`popupWanted`, que maneja su vista) o el widget de escritorio en modo letra.
Singleton {
    id: root

    property bool popupWanted: false
    readonly property bool desktopWanted: Config.widgetMediaEnabled && Config.widgetMediaMode === "lyrics"
        && !GameMode.active
    readonly property bool wanted: popupWanted || desktopWanted

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

    // Tema de la búsqueda en curso. Cambiar de tema mientras corre no la
    // corta: su resultado se descarta al llegar y recién entonces se busca
    // el tema pendiente, así una respuesta tardía no pisa la letra actual.
    property string fetchKey: ""
    property bool fetching: false
    property bool fetchOutputDone: false
    property bool fetchExited: false

    function load(): void {
        if (!wanted || !trackKey || trackKey === loadedKey) return;
        loadedKey = trackKey;
        status = "loading";
        lines = [];
        synced = false;
        if (!fetching) start();
    }

    function start(): void {
        // El pedido pendiente pudo quedar viejo mientras esperaba.
        if (!wanted || !loadedKey || loadedKey !== trackKey) {
            loadedKey = "";
            fetching = false;
            return;
        }
        fetching = true;
        fetchKey = loadedKey;
        fetchOutputDone = false;
        fetchExited = false;
        fetcher.command = ["python3", Quickshell.shellPath("scripts/lyrics.py"),
            Media.title, Media.artist, Media.album, String(Math.round(Media.duration))];
        fetcher.running = true;
    }

    // Se espera la salida y el fin del proceso (en cualquier orden) antes de
    // lanzar otra búsqueda, para no mezclar la salida de dos procesos.
    function finish(): void {
        if (!fetchOutputDone || !fetchExited) return;
        if (loadedKey && loadedKey !== fetchKey) Qt.callLater(start);
        else fetching = false;
    }

    onWantedChanged: load()
    onTrackKeyChanged: load()

    Process {
        id: fetcher

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.fetchKey === root.loadedKey) {
                    try {
                        const result = JSON.parse(text);
                        root.synced = result.synced;
                        root.lines = result.lines;
                        root.status = result.lines.length > 0 ? "found" : "none";
                    } catch (e) {
                        root.status = "none";
                    }
                }
                root.fetchOutputDone = true;
                root.finish();
            }
        }

        onExited: code => {
            if (code !== 0 && root.fetchKey === root.loadedKey) {
                root.status = "none";
                root.loadedKey = ""; // reintentar la próxima vez
            }
            root.fetchExited = true;
            root.finish();
        }
    }
}
