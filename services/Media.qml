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
    readonly property string artUrl: active?.trackArtUrl ?? ""

    function togglePlaying(): void {
        if (active?.canTogglePlaying) active.togglePlaying();
    }

    function next(): void {
        if (active?.canGoNext) active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious) active.previous();
    }
}
