pragma Singleton
import QtQuick
import Quickshell

// Tokens de diseño de Elaren: colores, formas, tipografía y movimiento.
QtObject {
    id: root

    // ── Paleta ────────────────────────────────────────────────────────────
    readonly property color surface: "#1e1e2e"
    readonly property color surfaceContainer: "#282839"
    readonly property color surfaceHigh: "#33334a"
    readonly property color outline: "#45455e"
    readonly property color text: "#e6e1e5"
    readonly property color textMuted: "#a9a4bb"
    readonly property color primary: "#a6c8ff"
    readonly property color textOnPrimary: "#0b2a52"
    readonly property color secondary: "#cdb4ff"
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color error: "#f38ba8"

    // Superficies translúcidas (sobre desenfoque de KWin)
    readonly property color glass: Qt.alpha(surface, 0.68)
    readonly property color glassBorder: Qt.alpha("white", 0.08)
    readonly property color glassHighlight: Qt.alpha("white", 0.05)
    readonly property color group: Qt.alpha("#4a4a6a", 0.32)
    readonly property color groupActive: Qt.alpha(primary, 0.2)

    // ── Forma y espacio ───────────────────────────────────────────────────
    component Radii: QtObject {
        readonly property int small: 8
        readonly property int normal: 12
        readonly property int large: 18
        readonly property int full: 999
    }
    readonly property Radii radius: Radii {}

    component Spacings: QtObject {
        readonly property int small: 4
        readonly property int normal: 8
        readonly property int large: 12
    }
    readonly property Spacings spacing: Spacings {}

    component BarMetrics: QtObject {
        readonly property int height: 44
        readonly property int margin: 6
        readonly property int itemHeight: 28
    }
    readonly property BarMetrics bar: BarMetrics {}

    // ── Tipografía ────────────────────────────────────────────────────────
    component Fonts: QtObject {
        readonly property string family: "Inter, Noto Sans, sans-serif"
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string icons: "Material Symbols Rounded"
        readonly property int small: 11
        readonly property int normal: 13
        readonly property int large: 15
        readonly property int icon: 18
    }
    readonly property Fonts font: Fonts {}

    // ── Movimiento ────────────────────────────────────────────────────────
    // ELAREN_ANIM_SCALE=0 desactiva las animaciones; 2 las hace el doble de lentas.
    component Motion: QtObject {
        readonly property real scale: {
            const v = parseFloat(Quickshell.env("ELAREN_ANIM_SCALE"));
            return isNaN(v) || v < 0 ? 1 : v;
        }
        readonly property int fast: 150 * scale
        readonly property int normal: 280 * scale
        readonly property int slow: 450 * scale
        readonly property int extraSlow: 700 * scale

        // Curvas Material 3 (bezierCurve de QtQuick: x1,y1,x2,y2,1,1)
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        // Con rebote: para cosas que "aparecen" o se desplazan
        readonly property list<real> expressive: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> expressiveFast: [0.42, 1.67, 0.21, 0.9, 1, 1]
    }
    readonly property Motion anim: Motion {}
}
