import Quickshell
import QtQuick
import "../../theme"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 36
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 12
        color: Theme.surface

        Text {
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 14
            text: Qt.formatDateTime(clock.date, "HH:mm  ·  dddd d MMM")
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
}
