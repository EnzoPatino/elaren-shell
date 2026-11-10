import QtQuick
import Quickshell
import "../../config"
import "../../services"

// Todos los widgets de escritorio de una pantalla. Cada uno se crea solo si
// está activado en Configuración → Widgets.
Scope {
    id: root

    required property var screen

    LazyLoader {
        active: Config.widgetClockEnabled
        ClockWidget { screen: root.screen }
    }

    LazyLoader {
        active: Config.widgetGreetingEnabled
        GreetingWidget { screen: root.screen }
    }

    // La tarjeta de música solo aparece si hay un reproductor abierto.
    LazyLoader {
        active: Config.widgetMediaEnabled && Media.available
        NowPlayingWidget { screen: root.screen }
    }

    LazyLoader {
        active: Config.widgetSystemEnabled
        SystemMonitorWidget { screen: root.screen }
    }

    LazyLoader {
        active: Config.widgetWeatherEnabled
        WeatherWidget { screen: root.screen }
    }
}
