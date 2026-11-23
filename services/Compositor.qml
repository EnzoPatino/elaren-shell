pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ventanas, escritorios y capturas, sin importar el compositor. Los módulos
// usan solo este servicio; detrás hay un backend por compositor:
//   - KWin (Plasma): services/KWin.qml, con el puente scripts/kwin-bridge.py.
//   - Hyprland: services/backends/HyprlandBackend.qml, con Quickshell.Hyprland.
// El de Hyprland se crea solo en Hyprland (así Plasma no necesita ese módulo
// de Quickshell) y el singleton KWin solo se crea si se lo usa.
//
// Ventana: { id, appId, resourceClass, minimized, onAllDesktops, desktops }
// Escritorio: { id, name }
Singleton {
    id: root

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string name: hyprland ? "hyprland" : "kwin"

    // KWin o HyprlandBackend: `var` porque los dos no comparten un tipo QML.
    readonly property var backend: {
        if (!hyprland) return KWin;
        const component = Qt.createComponent("backends/HyprlandBackend.qml");
        if (component.status === Component.Ready) return component.createObject(root);
        console.warn("compositor: no pude cargar el backend de Hyprland:", component.errorString());
        return null;
    }

    readonly property bool connected: backend?.connected ?? false
    readonly property list<var> desktops: backend?.desktops ?? []
    readonly property string currentDesktop: backend?.currentDesktop ?? ""
    // Nombre de la pantalla enfocada ("" si el compositor no lo informa).
    readonly property string focusedScreen: backend?.focusedScreen ?? ""
    readonly property string activeWindow: backend?.activeWindow ?? ""
    readonly property list<var> windows: backend?.windows ?? []
    // id de ventana → título actual (cambia mucho más seguido que `windows`)
    readonly property var captions: backend?.captions ?? ({})

    readonly property int currentDesktopIndex: desktops.findIndex(d => d.id === currentDesktop)

    function windowsOn(desktopId: string): list<var> {
        return windows.filter(w => w.onAllDesktops || w.desktops.includes(desktopId));
    }

    function activate(id: string): void { backend?.activate(id); }
    function toggle(id: string): void { backend?.toggle(id); }
    function close(id: string): void { backend?.close(id); }
    function switchDesktop(id: string): void { backend?.switchDesktop(id); }
    function stepDesktop(step: int): void { backend?.stepDesktop(step); }

    // ── Capturas ──────────────────────────────────────────────────────────
    // Hay una captura de pantalla en curso: los popups de la barra se ocultan
    // al instante para no tapar el selector ni salir en la foto.
    readonly property bool screenshotOverlay: backend?.screenshotOverlay ?? false
    property bool screenshotPending: false
    readonly property bool screenshotActive: screenshotOverlay || screenshotPending

    Connections {
        target: root.backend

        // KWin: el puente ya ve el selector de Spectacle (que tapa todo).
        // Hyprland: terminó scripts/screenshot.sh.
        function onScreenshotSettled(): void {
            pendingClear.stop();
            root.screenshotPending = false;
        }
    }

    // Captura "limpia": oculta los popups, espera a que se borren de la
    // pantalla y recién entonces captura. Pensado para asignarle la tecla
    // Impr Pant (ver README):
    //   qs ipc -p <ruta>/shell.qml call screenshot region
    // Modos: region, fullscreen, window (ventana activa), monitor.
    IpcHandler {
        target: "screenshot"

        function region(): void { root.screenshot("region"); }
        function fullscreen(): void { root.screenshot("fullscreen"); }
        function window(): void { root.screenshot("window"); }
        function monitor(): void { root.screenshot("monitor"); }
    }

    property string pendingMode: ""
    function screenshot(mode: string): void {
        if (!backend) return;
        pendingMode = mode;
        screenshotPending = true;
        launchShot.restart();
    }

    Timer {
        id: launchShot
        // Un par de cuadros para que el compositor ya no muestre los popups.
        interval: 120
        onTriggered: {
            root.backend.screenshot(root.pendingMode);
            // En Hyprland el selector puede quedar abierto un rato: ahí manda
            // el fin del script, con un respaldo largo por si se cuelga.
            pendingClear.interval = root.hyprland ? 60000 : 2500;
            pendingClear.restart();
        }
    }

    // Respaldo por si el puente de KWin no ve la ventana de Spectacle (o en
    // modos sin selector, donde no aparece ninguna), o por si el script de
    // Hyprland no termina nunca: los popups no pueden quedar ocultos.
    Timer {
        id: pendingClear
        interval: 2500
        onTriggered: root.screenshotPending = false
    }
}
