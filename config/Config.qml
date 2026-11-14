pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Preferencias de usuario de Elaren.
//
// Se guardan en ~/.config/elaren/settings.json y se editan desde el panel de
// Configuración (o a mano: el archivo se recarga solo al guardarlo). Cada
// propiedad tiene su valor por defecto en `store`; los nombres son los que
// usa el resto de la shell.
Singleton {
    id: root

    readonly property string directory: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/elaren`
    readonly property string file: `${directory}/settings.json`

    // ── Visualizador de escritorio ────────────────────────────────────────
    // Barras/onda sobre el fondo (debajo de las ventanas) mientras suena música.
    property alias visualizerEnabled: store.visualizerEnabled
    // "bars" | "blocks" | "wave" | "mirror" | "line"
    property alias visualizerStyle: store.visualizerStyle
    property alias visualizerHeight: store.visualizerHeight
    property alias visualizerOpacity: store.visualizerOpacity
    property alias visualizerBars: store.visualizerBars
    // "cover" (color de la portada) | "accent" (color del tema) | "rainbow"
    property alias visualizerColor: store.visualizerColor
    property alias visualizerCaps: store.visualizerCaps
    // Ancho de cada barra respecto de su hueco (0.2 finas … 0.95 juntas)
    property alias visualizerBarWidth: store.visualizerBarWidth
    // Multiplicador de sensibilidad (cuánto "saltan")
    property alias visualizerGain: store.visualizerGain
    // Ubicación: posición (fracción del espacio libre, 0..1, como los
    // widgets), largo (fracción del borde de la pantalla a lo largo de las
    // barras) y hacia dónde crecen las barras: "up" | "down" | "left" | "right".
    // Se acomoda con el ratón: Configuración → Visualizador → "Mover", o
    // qs ipc -p <ruta>/shell.qml call visualizer place
    property alias visualizerX: store.visualizerX
    property alias visualizerY: store.visualizerY
    property alias visualizerLength: store.visualizerLength
    property alias visualizerDirection: store.visualizerDirection

    // ── Apariencia ────────────────────────────────────────────────────────
    // Ver Theme.accentPresets
    property alias accent: store.accent
    // Velocidad de las animaciones (0 = sin animaciones). ELAREN_ANIM_SCALE manda.
    property alias animationScale: store.animationScale

    // ── Widgets de escritorio ─────────────────────────────────────────────
    // Cada widget: activado + posición (fracción del espacio libre, 0..1).
    // Se arrastran con el ratón salvo que `widgetsLocked` esté activo.
    property alias widgetsLocked: store.widgetsLocked
    property alias widgetScale: store.widgetScale
    // Tarjeta de vidrio detrás de cada widget (si no, solo texto con sombra)
    property alias widgetCards: store.widgetCards
    // "digital" | "analog" | "words"
    property alias widgetClockStyle: store.widgetClockStyle
    property alias widgetClockSeconds: store.widgetClockSeconds
    // Ciudad para el clima (Open-Meteo). Vacío = sin clima.
    property alias weatherCity: store.weatherCity
    property alias widgetClockEnabled: store.widgetClockEnabled
    property alias widgetClockX: store.widgetClockX
    property alias widgetClockY: store.widgetClockY
    property alias widgetGreetingEnabled: store.widgetGreetingEnabled
    property alias widgetGreetingX: store.widgetGreetingX
    property alias widgetGreetingY: store.widgetGreetingY
    property alias widgetMediaEnabled: store.widgetMediaEnabled
    property alias widgetMediaX: store.widgetMediaX
    property alias widgetMediaY: store.widgetMediaY
    property alias widgetSystemEnabled: store.widgetSystemEnabled
    property alias widgetSystemX: store.widgetSystemX
    property alias widgetSystemY: store.widgetSystemY
    property alias widgetWeatherEnabled: store.widgetWeatherEnabled
    property alias widgetWeatherX: store.widgetWeatherX
    property alias widgetWeatherY: store.widgetWeatherY

    // ── Barra superior ────────────────────────────────────────────────────
    // Borde de la pantalla: "top" | "bottom" | "left" | "right".
    property alias barPosition: store.barPosition
    property alias barShowWorkspaces: store.barShowWorkspaces
    // Cómo se rotulan los escritorios: "numbers" | "roman" | "kanji" | "dots"
    property alias barWorkspaceStyle: store.barWorkspaceStyle
    property alias barShowActiveWindow: store.barShowActiveWindow
    property alias barShowCaffeine: store.barShowCaffeine
    property alias barShowNetwork: store.barShowNetwork
    property alias barShowBrightness: store.barShowBrightness
    property alias barShowVolume: store.barShowVolume
    property alias barShowBattery: store.barShowBattery
    // Forma del avatar de la isla central: "circle" | "squircle" | "flower" | "hexagon"
    property alias barAvatarShape: store.barAvatarShape
    // De dónde sale el avatar: "drawn" (dibujado por la shell a partir de una
    // semilla) | "plasma" (galería de avatares de Plasma) | "face" (~/.face)
    property alias barAvatarSource: store.barAvatarSource
    // Semilla del avatar dibujado: el mismo texto siempre da el mismo personaje
    property alias barAvatarSeed: store.barAvatarSeed
    // Imagen elegida de /usr/share/plasma/avatars cuando la fuente es "plasma"
    property alias barAvatarImage: store.barAvatarImage
    // Qué queda en el medio de la pantalla: "center" (la barra entera) | "clock" (avatar y reloj)
    property alias barAlignment: store.barAlignment
    property alias barShowAvatar: store.barShowAvatar
    property alias barAvatarFollow: store.barAvatarFollow
    // Al abrir la isla: volver a la última pestaña en vez de Inicio
    property alias barIslandRemember: store.barIslandRemember
    property alias barTabMusic: store.barTabMusic
    property alias barTabSystem: store.barTabSystem
    property alias barTabTray: store.barTabTray
    property alias barTabCalendar: store.barTabCalendar

    // ── Dock ──────────────────────────────────────────────────────────────
    property alias dockEnabled: store.dockEnabled
    // Se esconde cuando el ratón no está encima; aparece al tocar el borde inferior.
    property alias dockAutoHide: store.dockAutoHide
    property alias dockIconSize: store.dockIconSize
    property alias dockMagnification: store.dockMagnification
    // Ids de los .desktop fijados (sin la extensión).
    property alias pinnedApps: store.pinnedApps

    // ── Fondo ─────────────────────────────────────────────────────────────
    // Quién dibuja el fondo: "auto" (skwd-wall si su daemon corre en modo
    // standalone, si no Elaren) | "elaren" | "skwd". ELAREN_WALLPAPER_PROVIDER manda.
    readonly property string wallpaperProvider: Quickshell.env("ELAREN_WALLPAPER_PROVIDER") || store.wallpaperProvider
    property alias wallpaperProviderSetting: store.wallpaperProvider
    // Ruta a una imagen. Vacío = usar el wallpaper de Plasma. ELAREN_WALLPAPER manda.
    readonly property string wallpaper: Quickshell.env("ELAREN_WALLPAPER") || store.wallpaper
    property alias wallpaperSetting: store.wallpaper
    // Desplazamiento lateral del fondo al cambiar de escritorio (px por escritorio).
    property alias wallpaperParallax: store.wallpaperParallax

    // Vuelve una sección (o todo, con "") a sus valores por defecto.
    function reset(prefix: string): void {
        for (const key of Object.keys(defaults)) {
            if (!prefix || key.startsWith(prefix)) store[key] = defaults[key];
        }
    }

    readonly property var defaults: ({
        visualizerEnabled: true,
        visualizerStyle: "bars",
        visualizerHeight: 220,
        visualizerOpacity: 0.75,
        visualizerBars: 48,
        visualizerColor: "cover",
        visualizerCaps: true,
        visualizerBarWidth: 0.62,
        visualizerGain: 1.0,
        visualizerX: 0.5,
        visualizerY: 1.0,
        visualizerLength: 0.92,
        visualizerDirection: "up",
        accent: "blue",
        animationScale: 1.0,
        barShowWorkspaces: true,
        barPosition: "top",
        barWorkspaceStyle: "numbers",
        barShowActiveWindow: true,
        barShowCaffeine: true,
        barShowNetwork: true,
        barShowBrightness: true,
        barShowVolume: true,
        barShowBattery: true,
        barAvatarShape: "squircle",
        barAvatarSource: "drawn",
        barAvatarSeed: "elaren",
        barAvatarImage: "/usr/share/plasma/avatars/Konqi.png",
        barAlignment: "center",
        barShowAvatar: true,
        barAvatarFollow: true,
        barIslandRemember: false,
        barTabMusic: true,
        barTabSystem: true,
        barTabTray: true,
        barTabCalendar: true,
        widgetsLocked: false,
        widgetScale: 1.0,
        widgetCards: true,
        widgetClockStyle: "digital",
        widgetClockSeconds: false,
        widgetClockEnabled: true,
        widgetClockX: 0.03,
        widgetClockY: 0.05,
        widgetGreetingEnabled: true,
        widgetGreetingX: 0.03,
        widgetGreetingY: 0.42,
        widgetMediaEnabled: true,
        widgetMediaX: 0.03,
        widgetMediaY: 0.72,
        widgetSystemEnabled: false,
        widgetSystemX: 0.97,
        widgetSystemY: 0.45,
        widgetWeatherEnabled: false,
        widgetWeatherX: 0.97,
        widgetWeatherY: 0.05,
        weatherCity: "",
        dockEnabled: true,
        dockAutoHide: true,
        dockIconSize: 44,
        dockMagnification: true,
        wallpaperProvider: "auto",
        wallpaper: "",
        wallpaperParallax: 24
    })

    Process {
        running: true
        command: ["mkdir", "-p", root.directory]
        onExited: settingsFile.path = root.file
    }

    FileView {
        id: settingsFile

        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        // Cada cambio desde el panel se escribe al instante.
        onAdapterUpdated: writeAdapter()
        // Primera vez: crea el archivo con los valores por defecto.
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: store

            property bool visualizerEnabled: true
            property string visualizerStyle: "bars"
            property int visualizerHeight: 220
            property real visualizerOpacity: 0.75
            property int visualizerBars: 48
            property string visualizerColor: "cover"
            property bool visualizerCaps: true
            property real visualizerBarWidth: 0.62
            property real visualizerGain: 1.0
            property real visualizerX: 0.5
            property real visualizerY: 1.0
            property real visualizerLength: 0.92
            property string visualizerDirection: "up"

            property string accent: "blue"
            property real animationScale: 1.0

            property bool barShowWorkspaces: true
            property string barPosition: "top"
            property string barWorkspaceStyle: "numbers"
            property bool barShowActiveWindow: true
            property bool barShowCaffeine: true
            property bool barShowNetwork: true
            property bool barShowBrightness: true
            property bool barShowVolume: true
            property bool barShowBattery: true
            property string barAvatarShape: "squircle"
            property string barAvatarSource: "drawn"
            property string barAvatarSeed: "elaren"
            property string barAvatarImage: "/usr/share/plasma/avatars/Konqi.png"
            property string barAlignment: "center"
            property bool barShowAvatar: true
            property bool barAvatarFollow: true
            property bool barIslandRemember: false
            property bool barTabMusic: true
            property bool barTabSystem: true
            property bool barTabTray: true
            property bool barTabCalendar: true

            property bool widgetsLocked: false
            property real widgetScale: 1.0
            property bool widgetCards: true
            property string widgetClockStyle: "digital"
            property bool widgetClockSeconds: false
            property string weatherCity: ""
            property bool widgetClockEnabled: true
            property real widgetClockX: 0.03
            property real widgetClockY: 0.05
            property bool widgetGreetingEnabled: true
            property real widgetGreetingX: 0.03
            property real widgetGreetingY: 0.42
            property bool widgetMediaEnabled: true
            property real widgetMediaX: 0.03
            property real widgetMediaY: 0.72
            property bool widgetSystemEnabled: false
            property real widgetSystemX: 0.97
            property real widgetSystemY: 0.45
            property bool widgetWeatherEnabled: false
            property real widgetWeatherX: 0.97
            property real widgetWeatherY: 0.05

            property bool dockEnabled: true
            property bool dockAutoHide: true
            property int dockIconSize: 44
            property bool dockMagnification: true
            property list<string> pinnedApps: [
                "org.kde.dolphin",
                "app.zen_browser.zen",
                "Alacritty",
                "org.kde.discover",
                "systemsettings"
            ]

            property string wallpaperProvider: "auto"
            property string wallpaper: ""
            property int wallpaperParallax: 24
        }
    }
}
