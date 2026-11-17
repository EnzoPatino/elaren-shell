pragma Singleton
import QtQuick
import Quickshell

// Escritorios virtuales o espacios de trabajo (vía services/Compositor.qml).
Singleton {
    id: root

    readonly property list<var> list: Compositor.desktops
    readonly property int activeIndex: Compositor.currentDesktopIndex

    function isOccupied(index: int): bool {
        const desktop = list[index];
        return desktop ? Compositor.windowsOn(desktop.id).length > 0 : false;
    }

    function activate(index: int): void {
        const desktop = list[index];
        if (desktop) Compositor.switchDesktop(desktop.id);
    }

    function cycle(step: int): void {
        if (list.length > 0) Compositor.stepDesktop(step);
    }
}
