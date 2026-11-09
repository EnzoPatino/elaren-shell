import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Reloj central con dígitos que ruedan. Al hacer clic abre el calendario.
BarGroup {
    id: root

    property bool calendarOpen: false

    padding: Theme.spacing.large
    clickable: true
    color: calendarOpen ? Theme.groupActive : Theme.group

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: root.calendarOpen ? "calendar_month" : "schedule"
        color: Theme.primary
        font.pixelSize: Theme.font.large
    }

    RollingText {
        anchors.verticalCenter: parent.verticalCenter
        text: Time.time
        color: Theme.text
        font.family: Theme.font.family
        font.pixelSize: Theme.font.large
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: "·  " + Time.shortDate
        color: Theme.textMuted
        animate: true
    }
}
