pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Capa de widgets de escritorio: una sola ventana transparente a pantalla
// completa en la capa "Bottom" (encima del fondo, debajo de las ventanas).
//
// Todos los widgets viven acá adentro, así moverlos es puro QML (sin
// reubicar superficies) y va fluido. Mientras se arrastra uno, la capa
// muestra una grilla tenue y guías de alineación con imán (bordes y centro
// de la pantalla, y bordes/centros de los otros widgets).
PanelWindow {
    id: root

    readonly property bool anyEnabled: Config.widgetClockEnabled || Config.widgetGreetingEnabled
        || (Config.widgetMediaEnabled && Media.available) || Config.widgetSystemEnabled || Config.widgetWeatherEnabled

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: anyEnabled
    // Respeta la zona de la barra sin reservar espacio propio.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "elaren-widgets"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Solo los widgets reciben el ratón: sin máscara, la capa (a pantalla
    // completa) se tragaba todos los clics del escritorio de Plasma (menú
    // contextual, iconos, arrastrar archivos…). Mientras se arrastra uno, la
    // capa entera captura el ratón para que no se "escape" al moverlo rápido.
    mask: Region {
        item: canvas.activeWidget ? canvas : null

        Region { item: clock.item as Item }
        Region { item: greeting.item as Item }
        Region { item: media.item as Item }
        Region { item: system.item as Item }
        Region { item: weather.item as Item }
    }

    Item {
        id: canvas

        anchors.fill: parent

        // ── Estado del arrastre ───────────────────────────────────────────
        property Item activeWidget: null
        property list<real> guidesX: []
        property list<real> guidesY: []

        readonly property int margin: 24
        readonly property int threshold: 12
        readonly property int grid: 8

        readonly property list<Item> widgets: [clock.item, greeting.item, media.item, system.item, weather.item]
            .filter(w => w !== null && w !== undefined)

        function beginDrag(widget: Item): void {
            activeWidget = widget;
        }

        function endDrag(widget: Item): void {
            if (activeWidget === widget) activeWidget = null;
            guidesX = [];
            guidesY = [];
        }

        // Busca la línea de guía más cercana a alguno de los bordes/centro
        // del widget (offsets) y devuelve el corrimiento necesario.
        function nearest(position: real, size: real, lines: list<real>): var {
            let best = null;
            for (const offset of [0, size / 2, size]) {
                for (const line of lines) {
                    const delta = line - (position + offset);
                    if (Math.abs(delta) <= threshold && (!best || Math.abs(delta) < Math.abs(best.delta)))
                        best = { delta, line };
                }
            }
            return best;
        }

        // Posición propuesta → posición final con imanes, y guías a mostrar.
        function snap(widget: Item, px: real, py: real): var {
            const maxX = Math.max(0, width - widget.width);
            const maxY = Math.max(0, height - widget.height);
            let x = Math.max(0, Math.min(maxX, px));
            let y = Math.max(0, Math.min(maxY, py));

            const linesX = [margin, width / 2, width - margin];
            const linesY = [margin, height / 2, height - margin];
            for (const other of widgets) {
                if (other === widget) continue;
                linesX.push(other.x, other.x + other.width / 2, other.x + other.width);
                linesY.push(other.y, other.y + other.height / 2, other.y + other.height);
            }

            const bx = nearest(x, widget.width, linesX);
            const by = nearest(y, widget.height, linesY);
            if (bx) x += bx.delta; else x = Math.round(x / grid) * grid;
            if (by) y += by.delta; else y = Math.round(y / grid) * grid;

            guidesX = bx ? [bx.line] : [];
            guidesY = by ? [by.line] : [];
            return { x: Math.max(0, Math.min(maxX, x)), y: Math.max(0, Math.min(maxY, y)) };
        }

        // ── Grilla tenue mientras se arrastra ─────────────────────────────
        Canvas {
            id: dots

            anchors.fill: parent
            opacity: canvas.activeWidget ? 0.5 : 0
            visible: opacity > 0.01

            Behavior on opacity { Anim { duration: Theme.anim.normal } }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Qt.alpha(Theme.text, 0.35);
                const step = 32;
                for (let x = step; x < width; x += step)
                    for (let y = step; y < height; y += step)
                        ctx.fillRect(x - 1, y - 1, 2, 2);
            }
        }

        // ── Guías de alineación ───────────────────────────────────────────
        Repeater {
            model: canvas.guidesX

            Rectangle {
                required property real modelData
                x: Math.round(modelData)
                width: 1
                height: canvas.height
                color: Theme.primary

                // Aparece con un fundido corto
                Anim on opacity { from: 0; to: 0.85; duration: Theme.anim.fast }
            }
        }

        Repeater {
            model: canvas.guidesY

            Rectangle {
                required property real modelData
                y: Math.round(modelData)
                width: canvas.width
                height: 1
                color: Theme.primary

                // Aparece con un fundido corto
                Anim on opacity { from: 0; to: 0.85; duration: Theme.anim.fast }
            }
        }

        // ── Widgets ───────────────────────────────────────────────────────
        // Loader en vez de crear todos: un widget apagado no consume nada.
        Loader {
            id: clock
            z: (item as DesktopWidget)?.dragging ? 10 : 0
            active: Config.widgetClockEnabled
            sourceComponent: ClockWidget { area: canvas }
        }

        Loader {
            id: greeting
            z: (item as DesktopWidget)?.dragging ? 10 : 0
            active: Config.widgetGreetingEnabled
            sourceComponent: GreetingWidget { area: canvas }
        }

        // La tarjeta de música solo aparece si hay un reproductor abierto.
        Loader {
            id: media
            z: (item as DesktopWidget)?.dragging ? 10 : 0
            active: Config.widgetMediaEnabled && Media.available
            sourceComponent: NowPlayingWidget { area: canvas }
        }

        Loader {
            id: system
            z: (item as DesktopWidget)?.dragging ? 10 : 0
            active: Config.widgetSystemEnabled
            sourceComponent: SystemMonitorWidget { area: canvas }
        }

        Loader {
            id: weather
            z: (item as DesktopWidget)?.dragging ? 10 : 0
            active: Config.widgetWeatherEnabled
            sourceComponent: WeatherWidget { area: canvas }
        }
    }
}
