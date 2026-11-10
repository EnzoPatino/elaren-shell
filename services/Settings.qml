pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado del panel de Configuración.
//   qs ipc -p <ruta>/shell.qml call settings toggle
//   qs ipc -p <ruta>/shell.qml call settings openPage visualizer
Singleton {
    id: root

    property bool open: false
    property string page: "visualizer"

    function toggle(): void { open = !open; }
    function show(name: string): void {
        if (name) page = name;
        open = true;
    }
    function hide(): void { open = false; }

    IpcHandler {
        target: "settings"

        function toggle(): void { root.toggle(); }
        function close(): void { root.hide(); }
        function openPage(name: string): void { root.show(name); }
    }
}
