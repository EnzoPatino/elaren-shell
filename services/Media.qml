pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Reproductor MPRIS "activo": el que está sonando o, si no, el primero.
Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    readonly property MprisPlayer active: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property bool available: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle || "Sin título"
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string playerName: active?.identity ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    readonly property real position: active?.position ?? 0
    readonly property real duration: active?.length ?? 0
    readonly property bool hasProgress: (active?.lengthSupported ?? false) && duration > 0
    readonly property bool canSeek: active?.canSeek ?? false
    readonly property bool shuffleSupported: active?.shuffleSupported ?? false
    readonly property bool shuffled: active?.shuffle ?? false
    readonly property bool canScrub: canSeek && (active?.positionSupported ?? false) && hasProgress
    readonly property real progress: hasProgress
        ? Math.max(0, Math.min(1, position / duration))
        : 0
    readonly property string positionText: formatTime(position)
    readonly property string durationText: hasProgress ? formatTime(duration) : "--:--"

    function formatTime(seconds: real): string {
        const total = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
        const minutes = Math.floor(total / 60);
        const rest = String(total % 60).padStart(2, "0");
        if (minutes >= 60) {
            return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}:${rest}`;
        }
        return `${minutes}:${rest}`;
    }

    function seekTo(seconds: real): void {
        if (!active || !canScrub) return;
        active.position = Math.max(0, Math.min(duration, seconds));
    }

    function seekBy(seconds: real): void {
        if (active?.canSeek) active.seek(seconds);
    }

    function toggleShuffle(): void {
        if (active?.canControl && active.shuffleSupported) active.shuffle = !active.shuffle;
    }

    function togglePlaying(): void {
        if (active?.canTogglePlaying) active.togglePlaying();
    }

    function next(): void {
        if (active?.canGoNext) active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious) active.previous();
    }

    // MPRIS evita publicar la posición a cada instante si nadie la observa.
    // Un pulso de 2 Hz mantiene el progreso legible sin trabajo por frame.
    Timer {
        interval: 500
        repeat: true
        running: root.playing && (root.active?.positionSupported ?? false)
        onTriggered: if (root.active?.positionSupported) root.active.positionChanged()
    }
}
