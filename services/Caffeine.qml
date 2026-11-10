pragma Singleton
import QtQuick
import Quickshell

// "Cafeína": mientras está activa la pantalla no se apaga ni se bloquea.
// La inhibición la hace un IdleInhibitor ligado a la ventana de la barra
// (ver modules/bar/Bar.qml).
Singleton {
    property bool enabled: false

    function toggle(): void {
        enabled = !enabled;
    }
}
