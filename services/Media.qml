pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../theme"

// Reproductor MPRIS "activo": el que está sonando o, si no, el primero.
Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values

    // Reproductor elegido a mano (selector del reproductor expandido). Si se
    // cierra, se vuelve a la elección automática.
    property MprisPlayer pinned: null
    readonly property MprisPlayer active: (pinned && players.includes(pinned) ? pinned : null)
        ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    function select(player: MprisPlayer): void {
        pinned = player;
    }

    readonly property bool available: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle || "Sin título"
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string playerName: active?.identity ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    // Number(...) || 0: al recargar o cerrarse el reproductor los valores
    // pueden llegar como undefined un instante.
    readonly property real position: Number(active?.position) || 0
    readonly property real duration: Number(active?.length) || 0
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
    readonly property string remainingText: hasProgress ? "-" + formatTime(duration - position) : "--:--"

    readonly property bool loopSupported: active?.loopSupported ?? false
    readonly property int loopState: active?.loopState ?? MprisLoopState.None
    readonly property bool volumeSupported: active?.volumeSupported ?? false
    readonly property real volume: active?.volume ?? 1

    // Color de acento sacado de la portada: el más vivo de la paleta,
    // aclarado si hace falta para que contraste sobre fondo oscuro.
    readonly property color accent: {
        const colors = quantizer.colors;
        if (!artLocal || colors.length === 0) return Theme.primary;
        let best = colors[0];
        let bestScore = -1;
        for (const c of colors) {
            const score = c.hsvSaturation * 0.7 + c.hsvValue * 0.3;
            if (score > bestScore) {
                best = c;
                bestScore = score;
            }
        }
        const s = Math.min(0.75, Math.max(0.35, best.hsvSaturation));
        return Qt.hsva(best.hsvHue < 0 ? 0.6 : best.hsvHue, s, Math.max(0.82, best.hsvValue), 1);
    }

    // ColorQuantizer solo lee archivos locales; las portadas web (p. ej. las
    // que publica el navegador) se descargan antes a un archivo temporal.
    property string artLocal: ""
    property int artDownloads: 0

    onArtUrlChanged: {
        if (/^https?:/.test(artUrl)) {
            artDownloads++;
            const file = `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/elaren-art-${artDownloads % 2}`;
            artFetch.target = file;
            artFetch.command = ["curl", "-sfL", "--max-time", "8", "-o", file, artUrl];
            artFetch.running = true;
        } else {
            artLocal = artUrl;
        }
    }

    Process {
        id: artFetch
        property string target
        onExited: code => root.artLocal = code === 0 ? `file://${target}` : ""
    }

    ColorQuantizer {
        id: quantizer
        source: root.artLocal
        depth: 3
        rescaleSize: 64
    }

    function cycleLoop(): void {
        if (!active?.canControl || !loopSupported) return;
        active.loopState = loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : loopState === MprisLoopState.Playlist ? MprisLoopState.Track
            : MprisLoopState.None;
    }

    function setVolume(value: real): void {
        if (active?.canControl && volumeSupported) active.volume = Math.max(0, Math.min(1, value));
    }

    function raise(): void {
        if (active?.canRaise) active.raise();
    }

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
