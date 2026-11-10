pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Visualizador de escritorio: barras estilo cava u ondas sobre el fondo de
// pantalla, debajo de las ventanas, mientras suena música.
//
// - Capa "Bottom" de layer-shell: encima del wallpaper, debajo de las ventanas.
// - No recibe clics (máscara vacía): el escritorio sigue usable.
// - Toma el color de la portada del tema que suena.
// - Aparece al reproducir y se desvanece al pausar; sin música no trabaja.
// - Estilo, color, tamaño, etc.: Configuración → Visualizador (o por IPC:
//   qs ipc -p <ruta>/shell.qml call visualizer cycle).
PanelWindow {
    id: root

    readonly property int maxHeight: Config.visualizerHeight
    readonly property int sideMargin: Math.round(width * 0.04)
    readonly property color accent: Config.visualizerColor === "cover" ? Media.accent : Theme.primary
    readonly property string style: Visualizer.style

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: maxHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "elaren-visualizer"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Región de entrada vacía: los clics pasan al escritorio.
    mask: Region {}

    // Aparece con la música; al pausar espera un poco antes de irse.
    property real amount: 0
    readonly property bool active: Media.playing
    onActiveChanged: {
        fade.duration = active ? 700 : 1600;
        amount = active ? 1 : 0;
    }
    Component.onCompleted: amount = active ? 1 : 0
    Behavior on amount { NumberAnimation { id: fade; easing.type: Easing.InOutQuad } }

    visible: amount > 0.001

    // El servicio sabe solo cuándo hace falta (visualizador activado y música
    // sonando): ver Visualizer.desktopActive.

    // El suavizado y las "tapitas" se calculan en el servicio: un
    // FrameAnimation dentro de esta ventana de fondo depende de que el
    // compositor le pida cuadros, y en la capa "Bottom" casi no lo hace.
    Item {
        id: stage
        anchors.fill: parent
        anchors.leftMargin: root.sideMargin
        anchors.rightMargin: root.sideMargin
        opacity: root.amount * Config.visualizerOpacity

        // Resplandor de color al pie, que sube con el volumen
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 1.05
            height: root.maxHeight * (0.35 + Visualizer.level * 0.5)
            opacity: 0.35
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha(root.accent, 0.45) }
            }
        }

        SpectrumView {
            anchors.fill: parent
            anchors.bottomMargin: 4
            values: Visualizer.display.map(v => v * root.amount)
            caps: Visualizer.caps.map(v => v * root.amount)
            style: root.style
            colorMode: Config.visualizerColor
            color: root.accent
            maxHeight: root.maxHeight
            barWidth: Config.visualizerBarWidth
            showCaps: Config.visualizerCaps
        }
    }
}
