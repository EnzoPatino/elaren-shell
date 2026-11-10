pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Monitor del sistema: anillos grandes de CPU, memoria y temperatura, con
// red y tiempo encendido debajo.
DesktopWidget {
    id: root

    key: "System"

    function levelColor(value: real): color {
        return value >= 0.9 ? Theme.error : value >= 0.75 ? Theme.warning : Theme.primary;
    }

    Column {
        spacing: 14

        Row {
            spacing: 22

            Repeater {
                model: [
                    { label: "CPU", value: () => SystemStats.cpu, text: () => Math.round(SystemStats.cpu * 100) + "%" },
                    { label: "RAM", value: () => SystemStats.memory, text: () => Math.round(SystemStats.memory * 100) + "%" },
                    { label: "TEMP", value: () => Math.max(0, SystemStats.cpuTemp) / 100, text: () => SystemStats.cpuTemp > 0 ? Math.round(SystemStats.cpuTemp) + "°" : "—" }
                ]

                Column {
                    id: gauge
                    required property var modelData
                    readonly property real value: modelData.value()
                    spacing: 6

                    Item {
                        width: 88
                        height: 88

                        Ring {
                            anchors.fill: parent
                            value: gauge.value
                            thickness: 8
                            color: root.levelColor(gauge.value)
                            trackColor: Qt.alpha(Theme.text, 0.12)
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: gauge.modelData.text()
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: gauge.modelData.label
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Repeater {
                model: [
                    { icon: "arrow_downward", text: () => SystemStats.formatBytes(SystemStats.netDown) + "/s" },
                    { icon: "arrow_upward", text: () => SystemStats.formatBytes(SystemStats.netUp) + "/s" },
                    { icon: "schedule", text: () => SystemStats.formatDuration(SystemStats.uptime) }
                ]

                Row {
                    id: stat
                    required property var modelData
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stat.modelData.icon
                        font.pixelSize: 15
                        color: Theme.primary
                        animateChange: false
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stat.modelData.text()
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small + 1
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
