pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower as UPower

// Perfil de energía del sistema (power-profiles-daemon o tuned-ppd, por DBus):
//
// - "saver":       Ahorro. Baja frecuencias y consumo; rinde menos pero dura
//                  más la batería y el equipo calienta menos.
// - "balanced":    Equilibrado. El modo normal: sube la potencia cuando hace
//                  falta y la baja en reposo.
// - "performance": Rendimiento. Prioriza la velocidad (juegos, compilar,
//                  renderizar) a costa de más consumo, calor y ventilador.
//
// No todos los equipos ofrecen "Rendimiento": ver `hasPerformance`.
Singleton {
    id: root

    readonly property var profiles: UPower.PowerProfiles
    readonly property bool hasPerformance: profiles.hasPerformanceProfile

    // Si no hay demonio de perfiles, PowerProfiles informa siempre Balanced:
    // se considera disponible solo si el servicio responde en el bus.
    property bool available: false

    readonly property string current: {
        switch (profiles.profile) {
        case UPower.PowerProfile.PowerSaver: return "saver";
        case UPower.PowerProfile.Performance: return "performance";
        default: return "balanced";
        }
    }

    // Motivo por el que el sistema bajó "Rendimiento" (p. ej. temperatura).
    readonly property string degradation: profiles.degradationReason === "lap-detected"
        ? "Bajado: el equipo está sobre las piernas"
        : profiles.degradationReason === "high-operating-temperature"
            ? "Bajado: temperatura alta"
            : ""

    readonly property var modes: hasPerformance ? ["saver", "balanced", "performance"] : ["saver", "balanced"]

    function label(mode: string): string {
        return { saver: "Ahorro", balanced: "Equilibrado", performance: "Rendimiento" }[mode] ?? "";
    }

    function iconFor(mode: string): string {
        return { saver: "eco", balanced: "balance", performance: "speed" }[mode] ?? "balance";
    }

    readonly property string icon: iconFor(current)

    function set(mode: string): void {
        const value = { saver: UPower.PowerProfile.PowerSaver,
                        balanced: UPower.PowerProfile.Balanced,
                        performance: UPower.PowerProfile.Performance }[mode];
        if (value !== undefined) profiles.profile = value;
    }

    // Ahorro → Equilibrado → Rendimiento → Ahorro…
    function cycle(): void {
        set(modes[(modes.indexOf(current) + 1) % modes.length]);
    }

    function openSettings(): void {
        Quickshell.execDetached(["kcmshell6", "kcm_powerdevilprofilesconfig"]);
    }

    Process {
        running: true
        command: ["busctl", "--system", "status", "org.freedesktop.UPower.PowerProfiles"]
        onExited: code => root.available = code === 0
    }
}
