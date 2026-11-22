pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez

// Bluetooth (BlueZ). `available` es falso si el equipo no tiene adaptador o
// el servicio `bluetooth` no está corriendo. Los dispositivos y la
// vinculación quedan en el módulo de Plasma; acá solo se prende, se apaga y se
// muestra qué está conectado.
Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false

    readonly property var connectedDevices: (adapter?.devices?.values ?? []).filter(d => d.connected)
    readonly property bool connected: enabled && connectedDevices.length > 0

    // Nombre del dispositivo conectado; con varios, el primero y cuántos más.
    readonly property string summary: {
        if (!available) return "Sin adaptador";
        if (!enabled) return "Apagado";
        if (!connected) return "Sin dispositivos";
        const first = connectedDevices[0].name || connectedDevices[0].deviceName;
        return connectedDevices.length > 1 ? `${first} +${connectedDevices.length - 1}` : first;
    }

    readonly property string icon: {
        if (!available || !enabled) return "bluetooth_disabled";
        if (connected) return "bluetooth_connected";
        return "bluetooth";
    }

    function toggle(): void {
        if (adapter) adapter.enabled = !adapter.enabled;
    }

    function openSettings(): void {
        Quickshell.execDetached(["kcmshell6", "kcm_bluetooth"]);
    }
}
