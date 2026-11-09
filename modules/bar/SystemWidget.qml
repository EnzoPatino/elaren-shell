pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Uso de CPU y RAM con anillos animados, más la temperatura de la CPU.
// Al pasar el ratón se despliega la velocidad de red. Clic: panel detallado.
BarGroup {
    id: root

    property bool popupOpen: false

    function levelColor(value: real): color {
        return value >= 0.9 ? Theme.error : value >= 0.75 ? Theme.warning : Theme.primary;
    }

    clickable: true
    padding: Theme.spacing.normal + 2
    color: popupOpen ? Theme.groupActive : Theme.group

    HoverHandler { id: hover }

    component Metric: Row {
        id: metric

        property real value: 0
        property string icon
        property color tint: root.levelColor(value)

        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            Ring {
                anchors.fill: parent
                value: metric.value
                color: metric.tint
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: metric.icon
                font.pixelSize: 11
                color: metric.tint
                animateChange: false
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            text: Math.round(metric.value * 100) + "%"
            font.pixelSize: Theme.font.small
            font.features: { "tnum": 1 }
        }
    }

    Metric {
        icon: "memory"
        value: SystemStats.cpu
    }

    Metric {
        icon: "memory_alt"
        value: SystemStats.memory
    }

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: SystemStats.cpuTemp > 0

        Row {
            spacing: 1

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "device_thermostat"
                font.pixelSize: Theme.font.normal
                color: SystemStats.cpuTemp >= 85 ? Theme.error : SystemStats.cpuTemp >= 70 ? Theme.warning : Theme.textMuted
                animateChange: false
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(SystemStats.cpuTemp) + "°"
                font.pixelSize: Theme.font.small
                font.features: { "tnum": 1 }
                color: Theme.textMuted
            }
        }
    }

    // Red: solo al pasar el ratón
    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: hover.hovered

        Row {
            spacing: 4
            leftPadding: 4

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_downward"
                font.pixelSize: Theme.font.normal
                color: Theme.primary
                animateChange: false
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                text: SystemStats.formatBytes(SystemStats.netDown)
                font.pixelSize: Theme.font.small
                font.features: { "tnum": 1 }
            }
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_upward"
                font.pixelSize: Theme.font.normal
                color: Theme.secondary
                animateChange: false
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                text: SystemStats.formatBytes(SystemStats.netUp)
                font.pixelSize: Theme.font.small
                font.features: { "tnum": 1 }
            }
        }
    }
}
