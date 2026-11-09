pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Iconos de aplicaciones resueltos a archivos (ver scripts/icon-resolver.py).
//
// Uso: Image { source: Icons.source("okular") }
// Devuelve "" mientras el nombre se resuelve; el binding se actualiza solo.
Singleton {
    id: root

    readonly property string fallbackName: "application-x-executable"

    // nombre → ruta (o null si no existe en el tema)
    property var paths: ({})

    property var pending: ({})
    property var queue: []
    property var incoming: ({})

    function source(name: string): string {
        const key = name || fallbackName;
        const path = paths[key];
        if (path === undefined) {
            request(key);
            return "";
        }
        if (path) return `file://${path}`;
        return key === fallbackName ? "" : source(fallbackName);
    }

    function request(name: string): void {
        if (pending[name]) return;
        pending[name] = true;
        queue.push(name);
        flush.restart();
    }

    // Envía los nombres pendientes al helper en un solo bloque.
    Timer {
        id: flush
        interval: 0
        onTriggered: {
            if (!resolver.running) {
                flush.interval = 200;
                flush.restart();
                return;
            }
            if (root.queue.length > 0) resolver.write(root.queue.join("\n") + "\n");
            root.queue = [];
        }
    }

    // Aplica las respuestas acumuladas de una vez (evita recalcular todos los
    // iconos por cada línea recibida).
    Timer {
        id: apply
        interval: 30
        onTriggered: {
            root.paths = Object.assign({}, root.paths, root.incoming);
            root.incoming = {};
        }
    }

    Process {
        id: resolver

        command: ["python3", Quickshell.shellPath("scripts/icon-resolver.py")]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line);
                    root.incoming[result.name] = result.path;
                    apply.restart();
                } catch (e) {
                    console.warn("icon-resolver:", e);
                }
            }
        }

        onExited: {
            // Si el helper muere, se relanza y se vuelven a pedir los pendientes.
            root.pending = {};
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: resolver.running = true
    }

    // Pide de entrada los iconos de todas las apps instaladas.
    Component.onCompleted: {
        for (const app of DesktopEntries.applications.values) request(app.icon);
        request(fallbackName);
    }
}
