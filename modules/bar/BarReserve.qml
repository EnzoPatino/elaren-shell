import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"

// Reserva invisible del espacio de la barra. La barra se dibuja en una capa a
// pantalla completa que no reserva nada (para que la isla pueda crecer sin
// empujar ventanas); esta superficie vacía es la que les dice a las ventanas
// cuánto lugar dejar en el borde elegido.
PanelWindow {
    readonly property bool vertical: Config.barPosition === "left" || Config.barPosition === "right"

    anchors {
        top: Config.barPosition === "top" || vertical
        bottom: Config.barPosition === "bottom" || vertical
        left: Config.barPosition === "left" || !vertical
        right: Config.barPosition === "right" || !vertical
    }
    implicitWidth: vertical ? Theme.bar.height + 2 * Theme.spacing.large : 0
    implicitHeight: vertical ? 0 : Theme.bar.height + Theme.spacing.large
    color: "transparent"
    // Si la barra se oculta sola, las ventanas usan toda la pantalla.
    exclusionMode: Config.barAutoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "elaren-bar-reserve"
}
