pragma Singleton
import QtQuick
import Quickshell

// Preferencias de usuario de Elaren.
Singleton {
    // ── Fondo ─────────────────────────────────────────────────────────────
    // Quién dibuja el fondo:
    //   "auto"   → skwd-wall si su daemon corre en modo standalone, si no Elaren
    //   "elaren" → siempre Elaren (imagen de Plasma o `wallpaper`)
    //   "skwd"   → siempre skwd-wall (Elaren no dibuja nada)
    readonly property string wallpaperProvider: Quickshell.env("ELAREN_WALLPAPER_PROVIDER") || "auto"
    // Ruta a una imagen. Vacío = usar el wallpaper configurado en Plasma.
    // También se puede forzar con la variable de entorno ELAREN_WALLPAPER.
    readonly property string wallpaper: Quickshell.env("ELAREN_WALLPAPER") ?? ""
    // Desplazamiento lateral del fondo al cambiar de escritorio (px por escritorio).
    readonly property int wallpaperParallax: 24

    // ── Dock ──────────────────────────────────────────────────────────────
    readonly property bool dockEnabled: true
    // Se esconde cuando el ratón no está encima; aparece al tocar el borde inferior.
    readonly property bool dockAutoHide: true
    readonly property int dockIconSize: 44
    // Ids de los .desktop fijados (sin la extensión).
    readonly property list<string> pinnedApps: [
        "org.kde.dolphin",
        "app.zen_browser.zen",
        "Alacritty",
        "org.kde.discover",
        "systemsettings"
    ]
}
