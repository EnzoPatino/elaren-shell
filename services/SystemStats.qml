pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Métricas del sistema leídas de /proc y /sys (sin procesos externos en cada
// muestreo). Guarda un historial corto para los gráficos.
Singleton {
    id: root

    readonly property int interval: 2000
    readonly property int historyLength: 60

    // Fracciones 0..1
    property real cpu: 0
    property real memory: 0
    property real swap: 0
    property real gpu: -1 // -1 = sin dato

    // Bytes
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0

    // °C (-1 = sin sensor)
    property real cpuTemp: -1
    property real gpuTemp: -1

    // Bytes por segundo
    property real netDown: 0
    property real netUp: 0

    property real uptime: 0 // segundos

    property list<real> cpuHistory: []
    property list<real> memoryHistory: []
    property list<real> netDownHistory: []
    property list<real> netUpHistory: []

    // Rutas de sensores (se descubren al arrancar porque el número de hwmon cambia)
    property string cpuTempPath: ""
    property string gpuTempPath: ""
    property string gpuBusyPath: ""

    property var previousCpu: null
    property var previousNet: null

    function formatBytes(bytes: real): string {
        const units = ["B", "K", "M", "G", "T"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return (value >= 100 || unit === 0 ? value.toFixed(0) : value.toFixed(1)) + units[unit];
    }

    function formatDuration(seconds: real): string {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    function pushHistory(list: list<real>, value: real): list<real> {
        const next = list.slice(-(historyLength - 1));
        next.push(value);
        return next;
    }

    function parseCpu(text: string): void {
        const fields = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = fields[3] + (fields[4] ?? 0);
        const total = fields.reduce((a, b) => a + b, 0);
        if (previousCpu) {
            const dTotal = total - previousCpu.total;
            const dIdle = idle - previousCpu.idle;
            cpu = dTotal > 0 ? Math.max(0, Math.min(1, 1 - dIdle / dTotal)) : 0;
            cpuHistory = pushHistory(cpuHistory, cpu);
        }
        previousCpu = { total, idle };
    }

    function parseMemory(text: string): void {
        const info = {};
        for (const line of text.split("\n")) {
            const match = line.match(/^(\w+):\s+(\d+)/);
            if (match) info[match[1]] = Number(match[2]) * 1024;
        }
        memoryTotal = info.MemTotal ?? 0;
        memoryUsed = memoryTotal - (info.MemAvailable ?? 0);
        memory = memoryTotal > 0 ? memoryUsed / memoryTotal : 0;
        swapTotal = info.SwapTotal ?? 0;
        swapUsed = swapTotal - (info.SwapFree ?? 0);
        swap = swapTotal > 0 ? swapUsed / swapTotal : 0;
        memoryHistory = pushHistory(memoryHistory, memory);
    }

    function parseNet(text: string): void {
        let rx = 0;
        let tx = 0;
        for (const line of text.split("\n").slice(2)) {
            const [name, data] = line.split(":");
            if (!data || name.trim() === "lo") continue;
            const fields = data.trim().split(/\s+/).map(Number);
            rx += fields[0];
            tx += fields[8];
        }
        const now = Date.now();
        if (previousNet) {
            const seconds = (now - previousNet.time) / 1000;
            if (seconds > 0) {
                netDown = Math.max(0, (rx - previousNet.rx) / seconds);
                netUp = Math.max(0, (tx - previousNet.tx) / seconds);
                netDownHistory = pushHistory(netDownHistory, netDown);
                netUpHistory = pushHistory(netUpHistory, netUp);
            }
        }
        previousNet = { rx, tx, time: now };
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            uptimeFile.reload();
            if (root.cpuTempPath) cpuTempFile.reload();
            if (root.gpuTempPath) gpuTempFile.reload();
            if (root.gpuBusyPath) gpuBusyFile.reload();
        }
    }

    FileView { id: stat; path: "/proc/stat"; onLoaded: root.parseCpu(text()) }
    FileView { id: meminfo; path: "/proc/meminfo"; onLoaded: root.parseMemory(text()) }
    FileView { id: netdev; path: "/proc/net/dev"; onLoaded: root.parseNet(text()) }
    FileView { id: uptimeFile; path: "/proc/uptime"; onLoaded: root.uptime = parseFloat(text()) }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }
    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        onLoaded: root.gpuTemp = parseInt(text()) / 1000
    }
    FileView {
        id: gpuBusyFile
        path: root.gpuBusyPath
        onLoaded: root.gpu = parseInt(text()) / 100
    }

    // Descubre sensores: k10temp/coretemp/zenpower para CPU, amdgpu para GPU.
    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
                [ -r "$h/temp1_input" ] && echo "hwmon $(cat "$h/name") $h/temp1_input"
            done
            for c in /sys/class/drm/card*/device/gpu_busy_percent; do
                [ -r "$c" ] && echo "gpubusy - $c"
            done`]
        stdout: SplitParser {
            onRead: line => {
                const [kind, name, path] = line.split(" ");
                if (kind === "gpubusy" && !root.gpuBusyPath) root.gpuBusyPath = path;
                else if (["k10temp", "coretemp", "zenpower", "cpu_thermal"].includes(name) && !root.cpuTempPath) root.cpuTempPath = path;
                else if (["amdgpu", "nouveau", "radeon"].includes(name) && !root.gpuTempPath) root.gpuTempPath = path;
            }
        }
    }
}
