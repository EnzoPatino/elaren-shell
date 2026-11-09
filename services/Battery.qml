pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Batería del portátil (UPower). `available` es falso en equipos de escritorio.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.ready && device?.isLaptopBattery
    readonly property real level: device?.percentage ?? 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: !charging && level <= 0.2
    readonly property bool critical: !charging && level <= 0.1

    readonly property string icon: {
        if (charging) return "battery_charging_full";
        if (full) return "battery_full";
        const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
                       "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
        return steps[Math.min(steps.length - 1, Math.floor(level * steps.length))];
    }
}
