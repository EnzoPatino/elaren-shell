pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Salida de audio por defecto (PipeWire).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.ready ?? false
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property string icon: {
        if (!ready) return "volume_off";
        if (muted || volume <= 0) return "volume_off";
        if (volume < 0.34) return "volume_mute";
        if (volume < 0.67) return "volume_down";
        return "volume_up";
    }

    function setVolume(value: real): void {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function changeVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (ready) sink.audio.muted = !sink.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    // Teclas de volumen en Hyprland (ver README):
    //   qs ipc -p <ruta>/shell.qml call volume up|down|mute
    IpcHandler {
        target: "volume"

        function up(): void { root.changeVolume(0.05); }
        function down(): void { root.changeVolume(-0.05); }
        function mute(): void { root.toggleMute(); }
        function set(percent: int): void { root.setVolume(percent / 100); }
        function get(): int { return Math.round(root.volume * 100); }
    }
}
