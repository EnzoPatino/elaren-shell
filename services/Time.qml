pragma Singleton
import QtQuick
import Quickshell

// Hora del sistema compartida por toda la shell.
Singleton {
    readonly property date date: clock.date ?? new Date()
    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string longDate: Qt.formatDateTime(clock.date, "dddd d MMMM")
    readonly property string shortDate: Qt.formatDateTime(clock.date, "ddd d MMM")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
