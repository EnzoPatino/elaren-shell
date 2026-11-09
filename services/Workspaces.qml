pragma Singleton
import QtQuick
import Quickshell
import Quickshell.WindowManager

// Escritorios virtuales vía ext-workspace-v1 (KWin en Plasma 6).
// Si el compositor no lo expone, `list` queda vacía y la barra oculta el módulo.
Singleton {
    id: root

    readonly property list<Windowset> list: WindowManager.windowsets.filter(w => w.shouldDisplay)
    readonly property int activeIndex: list.findIndex(w => w.active)

    function activate(index: int): void {
        const ws = list[index];
        if (ws?.canActivate) ws.activate();
    }

    // Cambia al escritorio siguiente/anterior (con vuelta circular).
    function cycle(step: int): void {
        if (list.length === 0) return;
        const from = activeIndex < 0 ? 0 : activeIndex;
        activate((from + step + list.length) % list.length);
    }
}
