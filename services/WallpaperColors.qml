pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../theme"
import "../components"

// Paleta de la shell sacada del fondo de pantalla (Configuración → Apariencia
// → "Colores del fondo").
//
// Sirve para cualquier fondo: la imagen de Elaren o de Plasma, y lo que ponga
// skwd-wall (imágenes, videos o escenas de Wallpaper Engine, usando la
// miniatura que guarda). Si un video no trae miniatura se saca un fotograma
// con ffmpeg, cuando está instalado. Al cambiar de fondo los colores pasan
// de una paleta a la otra con una transición.
//
// Le entrega a Theme un objeto con los colores (Theme.wallpaperPalette): con
// la opción apagada o sin fondo conocido, ese objeto vuelve a los colores de
// siempre, así prenderla y apagarla también es suave.
Singleton {
    id: root

    // La pantalla de bloqueo de Hyprland conserva su paleta fija.
    readonly property bool active: Config.themeFromWallpaper && !SessionLock.locked
    // Hay una paleta del fondo aplicada (para avisarlo en Configuración).
    readonly property bool ready: active && extracted !== null

    readonly property var videoExt: /\.(mp4|mkv|webm|mov|avi|m4v)$/i

    // ── De qué imagen sale ────────────────────────────────────────────────
    readonly property string skwdState: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/skwd-wall-v2/last-wallpaper.json`
    // Lo último que aplicó skwd-walld: { path, type, thumb }.
    property var skwd: null

    // Archivo (imagen, miniatura o video) del que salen los colores.
    readonly property string media: {
        if (Wallpaper.skwdDraws && skwd?.path) {
            if (skwd.type === "image" || Wallpaper.imageExt.test(skwd.path)) return skwd.path;
            return skwd.thumb || skwd.path;
        }
        return Wallpaper.source.replace(/^file:\/\//, "");
    }

    // Imagen lista para el ColorQuantizer (los videos pasan antes por ffmpeg).
    property string image: ""
    property int frames: 0

    function pickImage(): void {
        if (!active || !media) {
            image = "";
        } else if (videoExt.test(media)) {
            frames++;
            const out = `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/elaren-wallpaper-frame-${frames % 2}.jpg`;
            frameGrab.target = out;
            frameGrab.command = ["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", media,
                "-frames:v", "1", "-vf", "scale=256:-1", out];
            frameGrab.running = true;
        } else {
            image = `file://${media}`;
        }
    }
    onMediaChanged: pickImage()
    onActiveChanged: pickImage()
    Component.onCompleted: pickImage()

    FileView {
        path: root.active && Wallpaper.skwdDraws ? root.skwdState : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.skwd = JSON.parse(text());
            } catch (e) {}
        }
    }

    // Sin ffmpeg (o si falla) queda la paleta anterior.
    Process {
        id: frameGrab
        property string target
        onExited: code => {
            if (code === 0) root.image = `file://${target}`;
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root.image
        depth: 4
        rescaleSize: 96
    }

    // ── Paleta ────────────────────────────────────────────────────────────
    // Tonos de la imagen llevados a la paleta oscura de Elaren: el color más
    // vivo da el acento y tiñe apenas las superficies (menos cuanto más gris
    // es el fondo); el segundo tono que más se distingue, el acento secundario.
    readonly property var extracted: {
        const colors = quantizer.colors;
        if (!image || colors.length === 0) return null;

        const score = c => c.hsvSaturation * 0.7 + c.hsvValue * 0.3;
        const hue = c => c.hslHue < 0 ? 0.66 : c.hslHue;
        let best = colors[0];
        for (const c of colors) if (score(c) > score(best)) best = c;

        const h = hue(best);
        // Cuánto color tiene el fondo (0 = blanco y negro).
        const chroma = Math.min(1, best.hsvSaturation * Math.min(1, best.hsvValue * 1.6));
        const accentSat = chroma < 0.12 ? 0.12 : Math.min(0.8, Math.max(0.45, best.hslSaturation));

        let second = null;
        for (const c of colors) {
            const d = Math.abs(hue(c) - h);
            if (c.hsvSaturation < 0.2 || Math.min(d, 1 - d) < 0.08) continue;
            if (!second || score(c) > score(second)) second = c;
        }
        const h2 = second ? hue(second) : (h + 0.07) % 1;

        const tint = 0.06 + 0.16 * chroma;
        return {
            primary: Qt.hsla(h, accentSat, 0.78, 1),
            secondary: Qt.hsla(h2, accentSat, 0.8, 1),
            textOnPrimary: Qt.hsla(h, Math.min(0.6, accentSat), 0.16, 1),
            surface: Qt.hsla(h, tint, 0.14, 1),
            surfaceContainer: Qt.hsla(h, tint, 0.19, 1),
            surfaceHigh: Qt.hsla(h, tint, 0.245, 1),
            outline: Qt.hsla(h, tint * 0.9, 0.32, 1),
            text: Qt.hsla(h, 0.18, 0.9, 1),
            textMuted: Qt.hsla(h, 0.14, 0.69, 1),
            group: Qt.hsla(h, tint, 0.35, 1)
        };
    }

    readonly property var fallback: ({
        primary: Theme.accentPreset.primary,
        secondary: Theme.accentPreset.secondary,
        textOnPrimary: Theme.accentPreset.on,
        surface: Theme.basePalette.surface,
        surfaceContainer: Theme.basePalette.surfaceContainer,
        surfaceHigh: Theme.basePalette.surfaceHigh,
        outline: Theme.basePalette.outline,
        text: Theme.basePalette.text,
        textMuted: Theme.basePalette.textMuted,
        group: Theme.basePalette.group
    })

    readonly property var target: ready ? extracted : fallback

    QtObject {
        id: palette

        property color primary: root.target.primary
        property color secondary: root.target.secondary
        property color textOnPrimary: root.target.textOnPrimary
        property color surface: root.target.surface
        property color surfaceContainer: root.target.surfaceContainer
        property color surfaceHigh: root.target.surfaceHigh
        property color outline: root.target.outline
        property color text: root.target.text
        property color textMuted: root.target.textMuted
        property color group: root.target.group

        Behavior on primary { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on secondary { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on textOnPrimary { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on surface { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on surfaceContainer { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on surfaceHigh { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on outline { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on text { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on textMuted { CAnim { duration: Theme.anim.extraSlow } }
        Behavior on group { CAnim { duration: Theme.anim.extraSlow } }
    }

    Binding {
        target: Theme
        property: "wallpaperPalette"
        value: palette
    }
}
