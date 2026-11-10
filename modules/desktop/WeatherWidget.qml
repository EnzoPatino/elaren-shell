pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Clima actual y pronóstico de 3 días (Open-Meteo) para la ciudad configurada.
DesktopWidget {
    id: root

    key: "Weather"

    function dayName(iso: string): string {
        const d = new Date(iso + "T12:00:00");
        const s = Qt.locale().dayName(d.getDay(), Locale.ShortFormat);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    Column {
        spacing: 12

        // Sin ciudad, error o cargando
        StyledText {
            visible: !Weather.current
            width: 260
            wrapMode: Text.Wrap
            color: Theme.textMuted
            text: Config.weatherCity.trim() === "" ? "Elegí tu ciudad en Configuración → Widgets"
                : Weather.error !== "" ? Weather.error
                : "Cargando el clima…"
        }

        Row {
            visible: !!Weather.current
            spacing: 14

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.current ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"
                font.pixelSize: 64
                color: Theme.primary

                SequentialAnimation on rotation {
                    running: Theme.anim.scale > 0 && Weather.current?.code === 0 && Weather.current?.day === true
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 360; duration: 40000 }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: Weather.current ? `${Math.round(Weather.current.temp)}°` : ""
                    font.pixelSize: 52
                    font.weight: Font.Bold
                    animate: true
                }
                StyledText {
                    text: Weather.current ? Weather.describe(Weather.current.code) : ""
                    color: Theme.primary
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: Weather.place
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                }
            }
        }

        // Detalle: sensación, humedad, viento
        Row {
            visible: !!Weather.current
            spacing: 14

            Repeater {
                model: Weather.current ? [
                    { icon: "thermostat", text: `${Math.round(Weather.current.feels)}°` },
                    { icon: "water_drop", text: `${Weather.current.humidity}%` },
                    { icon: "air", text: `${Math.round(Weather.current.wind)} km/h` }
                ] : []

                Row {
                    id: detail
                    required property var modelData
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: detail.modelData.icon
                        font.pixelSize: 15
                        color: Theme.primary
                        animateChange: false
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: detail.modelData.text
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small + 1
                    }
                }
            }
        }

        // Próximos días
        Row {
            visible: Weather.daily.length > 1
            spacing: 10

            Repeater {
                model: Weather.daily.slice(1, 4)

                Rectangle {
                    id: day
                    required property var modelData
                    width: 76
                    height: 86
                    radius: 14
                    color: Qt.alpha(Theme.text, 0.06)

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dayName(day.modelData.date)
                            color: Theme.textMuted
                            font.pixelSize: Theme.font.small
                            font.weight: Font.Bold
                        }
                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.icon(day.modelData.code, true)
                            font.pixelSize: 24
                            color: Theme.primary
                            animateChange: false
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${Math.round(day.modelData.max)}° / ${Math.round(day.modelData.min)}°`
                            font.pixelSize: Theme.font.small
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
