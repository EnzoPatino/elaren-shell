pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Clima de la ciudad configurada (Configuración → Widgets), vía
// scripts/weather.py y Open-Meteo. Se actualiza cada 20 minutos y solo
// mientras el widget de clima está activado.
Singleton {
    id: root

    readonly property bool wanted: Config.widgetWeatherEnabled && Config.weatherCity.trim() !== ""

    property bool loading: false
    property string error: ""
    property string place: ""
    property var current: null
    property list<var> daily: []

    // Códigos WMO → descripción e icono de Material Symbols
    function describe(code: int): string {
        if (code === 0) return "Despejado";
        if (code <= 2) return "Algo nublado";
        if (code === 3) return "Nublado";
        if (code <= 48) return "Niebla";
        if (code <= 57) return "Llovizna";
        if (code <= 67) return "Lluvia";
        if (code <= 77) return "Nieve";
        if (code <= 82) return "Chaparrones";
        if (code <= 86) return "Nevadas";
        return "Tormenta";
    }

    function icon(code: int, day: bool): string {
        if (code === 0) return day ? "clear_day" : "clear_night";
        if (code <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3) return "cloud";
        if (code <= 48) return "foggy";
        if (code <= 67) return "rainy";
        if (code <= 77) return "weather_snowy";
        if (code <= 82) return "rainy";
        if (code <= 86) return "weather_snowy";
        return "thunderstorm";
    }

    function refresh(): void {
        if (!wanted || fetcher.running) return;
        loading = true;
        fetcher.command = ["python3", Quickshell.shellPath("scripts/weather.py"), Config.weatherCity.trim()];
        fetcher.running = true;
    }

    onWantedChanged: refresh()
    Connections {
        target: Config
        function onWeatherCityChanged() { root.current = null; root.refresh(); }
    }

    Timer {
        interval: 20 * 60 * 1000
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(text);
                    if (data.error) {
                        root.error = data.error;
                        return;
                    }
                    root.error = "";
                    root.place = data.place;
                    root.current = data.current;
                    root.daily = data.daily;
                } catch (e) {
                    root.error = "Respuesta inválida";
                }
            }
        }
    }
}
