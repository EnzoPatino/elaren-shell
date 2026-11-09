pragma Singleton
import QtQuick
import Quickshell

// Escritorios virtuales de KWin (vía el puente de services/KWin.qml).
Singleton {
    id: root

    readonly property list<var> list: KWin.desktops
    readonly property int activeIndex: KWin.currentDesktopIndex

    function isOccupied(index: int): bool {
        const desktop = list[index];
        return desktop ? KWin.windowsOn(desktop.id).length > 0 : false;
    }

    function activate(index: int): void {
        const desktop = list[index];
        if (desktop) KWin.switchDesktop(desktop.id);
    }

    function cycle(step: int): void {
        if (list.length > 0) KWin.stepDesktop(step);
    }
}
