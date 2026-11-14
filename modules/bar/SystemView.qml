pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Vista "Recursos" de la isla: gráficos de CPU, memoria y red, más sensores
// y tiempo encendido.
InlineCard {
    id: root

    cardWidth: 400

    component Chart: Column {
        id: chart

        property string title
        property string icon
        property string value
        property string detail
        property alias values: line.values
        property alias secondaryValues: line.secondaryValues
        property alias maximum: line.maximum
        property alias color: line.color

        width: parent.width
        spacing: 6

        Row {
            width: parent.width
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: chart.icon
                color: chart.color
                font.pixelSize: Theme.font.large
                animateChange: false
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chart.title
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chart.detail
                color: Theme.textMuted
                font.pixelSize: Theme.font.small
            }
        }

        Rectangle {
            width: parent.width
            height: 54
            radius: Theme.radius.normal
            color: Theme.surfaceContainer
            clip: true

            Sparkline {
                id: line
                anchors.fill: parent
                anchors.topMargin: 6
                capacity: SystemStats.historyLength
            }

            StyledText {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                text: chart.value
                font.pixelSize: Theme.font.large
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: chart.color
            }
        }
    }

    component Pill: Rectangle {
        id: pill

        property string icon
        property string label
        property string value

        width: (parent.width - Theme.spacing.normal) / 2
        height: 40
        radius: Theme.radius.normal
        color: Theme.surfaceContainer

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            spacing: 8

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                color: Theme.primary
                animateChange: false
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                StyledText {
                    text: pill.label
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
                StyledText {
                    text: pill.value
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacing.large

        Chart {
            title: "CPU"
            icon: "memory"
            value: Math.round(SystemStats.cpu * 100) + "%"
            detail: SystemStats.cpuTemp > 0 ? `${Math.round(SystemStats.cpuTemp)} °C` : ""
            values: SystemStats.cpuHistory
            maximum: 1
            color: Theme.primary
        }

        Chart {
            title: "Memoria"
            icon: "memory_alt"
            value: Math.round(SystemStats.memory * 100) + "%"
            detail: `${SystemStats.formatBytes(SystemStats.memoryUsed)} / ${SystemStats.formatBytes(SystemStats.memoryTotal)}`
            values: SystemStats.memoryHistory
            maximum: 1
            color: Theme.secondary
        }

        Chart {
            title: "Red"
            icon: "swap_vert"
            value: SystemStats.formatBytes(SystemStats.netDown) + "/s"
            detail: `↑ ${SystemStats.formatBytes(SystemStats.netUp)}/s`
            values: SystemStats.netDownHistory
            secondaryValues: SystemStats.netUpHistory
            maximum: 0
            color: Theme.success
        }

        Flow {
            width: parent.width
            spacing: Theme.spacing.normal

            Pill {
                icon: "videogame_asset"
                label: "GPU"
                value: SystemStats.gpu >= 0
                    ? `${Math.round(SystemStats.gpu * 100)}%` + (SystemStats.gpuTemp > 0 ? ` · ${Math.round(SystemStats.gpuTemp)} °C` : "")
                    : "—"
            }
            Pill {
                icon: "swap_horiz"
                label: "Swap"
                value: SystemStats.swapTotal > 0
                    ? `${SystemStats.formatBytes(SystemStats.swapUsed)} / ${SystemStats.formatBytes(SystemStats.swapTotal)}`
                    : "—"
            }
            Pill {
                icon: "schedule"
                label: "Encendido"
                value: SystemStats.formatDuration(SystemStats.uptime)
            }
            Rectangle {
                width: (parent.width - Theme.spacing.normal) / 2
                height: 40
                radius: Theme.radius.normal
                color: Theme.primary

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "monitoring"
                        color: Theme.textOnPrimary
                        animateChange: false
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Monitor"
                        color: Theme.textOnPrimary
                        font.weight: Font.DemiBold
                    }
                }

                StateLayer {
                    color: Theme.textOnPrimary
                    onClicked: {
                        Quickshell.execDetached(["plasma-systemmonitor"]);
                        root.dismissed();
                    }
                }
            }
        }
    }
}
