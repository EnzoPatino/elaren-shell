pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Control de la isla de la barra desde afuera (atajos del compositor):
//   qs ipc -p <ruta>/shell.qml call bar toggle wallpaper
//   qs ipc -p <ruta>/shell.qml call bar open calendar
//   qs ipc -p <ruta>/shell.qml call bar close
// Pestañas: home, music, system, tray, calendar, wallpaper. Hay una barra por
// pantalla: cada una escucha estas señales y solo responde la de la pantalla
// enfocada (modules/bar/Bar.qml).
Singleton {
    id: root

    // toggle: si la isla ya está abierta en esa pestaña, se cierra.
    signal openRequested(string tab, bool toggle)
    signal closeRequested()

    IpcHandler {
        target: "bar"

        function open(tab: string): void { root.openRequested(tab || "home", false); }
        function toggle(tab: string): void { root.openRequested(tab || "home", true); }
        function close(): void { root.closeRequested(); }
    }
}
