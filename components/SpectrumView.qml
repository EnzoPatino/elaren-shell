pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../theme"

// Dibuja un espectro de audio con distintos estilos. No calcula nada: recibe
// los valores (0..1) ya suavizados. Lo usan el visualizador de escritorio y
// las vistas previas del panel de Configuración.
//
// Estilos: "bars" (cava), "blocks" (vúmetro LED), "wave" (onda rellena),
// "mirror" (onda espejada), "line" (solo la línea).
Item {
    id: root

    // Arrays de JS (no `list<real>`): cada barra indexa estos valores en cada
    // cuadro, y una `list<real>` se copia entera en cada acceso.
    property var values: []
    property var caps: []
    property string style: "bars"
    // "cover"/"accent" usan `color`; "rainbow" pinta un arcoíris.
    property string colorMode: "accent"
    property color color: Theme.primary
    property real maxHeight: height - 12
    property real barWidth: 0.62     // fracción del hueco de cada barra
    property bool showCaps: true
    property real lineWidth: 2.5

    readonly property int count: values?.length ?? 0
    readonly property bool rainbow: colorMode === "rainbow"

    function colorAt(fraction: real): color {
        return rainbow ? Qt.hsva(0.75 - fraction * 0.75, 0.55, 1, 1) : root.color;
    }

    // ── bars / blocks ─────────────────────────────────────────────────────
    Item {
        id: barsLayer
        anchors.fill: parent
        opacity: root.style === "bars" || root.style === "blocks" ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        readonly property real slot: width / Math.max(1, root.count)
        readonly property real thickness: Math.max(2, slot * root.barWidth)
        readonly property bool blocks: root.style === "blocks"
        readonly property real blockSize: Math.max(3, thickness * 0.55)

        Repeater {
            model: root.count

            Item {
                id: bar

                required property int index
                // Con otro estilo activo las barras no se recalculan.
                readonly property real value: barsLayer.visible ? (root.values[index] ?? 0) : 0
                readonly property real fraction: index / Math.max(1, root.count - 1)
                readonly property color tint: root.colorAt(fraction)
                readonly property real barHeight: 3 + root.maxHeight * Math.min(1, value)

                x: index * barsLayer.slot + (barsLayer.slot - barsLayer.thickness) / 2
                width: barsLayer.thickness
                height: parent.height

                // Barra continua
                Rectangle {
                    visible: !barsLayer.blocks
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: parent.width
                    height: bar.barHeight
                    radius: Math.min(width / 2, 6)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(bar.tint, 1.3) }
                        GradientStop { position: 0.6; color: bar.tint }
                        GradientStop { position: 1; color: Qt.alpha(bar.tint, 0.25) }
                    }
                }

                // Bloques tipo LED: se encienden de abajo hacia arriba
                Column {
                    visible: barsLayer.blocks
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    spacing: 2
                    rotation: 180

                    Repeater {
                        model: Math.max(1, Math.floor(root.maxHeight / (barsLayer.blockSize + 2)))

                        Rectangle {
                            required property int index
                            readonly property real level: (index + 1) * (barsLayer.blockSize + 2)

                            width: bar.width
                            height: barsLayer.blockSize
                            radius: 1.5
                            color: index * (barsLayer.blockSize + 2) > root.maxHeight * 0.8
                                ? Qt.lighter(bar.tint, 1.5) : bar.tint
                            opacity: level <= bar.barHeight + barsLayer.blockSize ? 1 : 0.07
                        }
                    }
                }

                // Tapita que cae despacio
                Rectangle {
                    visible: root.showCaps && !barsLayer.blocks
                    width: parent.width
                    height: 3
                    radius: 1.5
                    y: parent.height - 4 - 3 - root.maxHeight * Math.min(1, barsLayer.visible ? (root.caps[bar.index] ?? 0) : 0) - 6
                    color: Qt.lighter(bar.tint, 1.5)
                    opacity: 0.85
                }
            }
        }
    }

    // ── wave / mirror / line ──────────────────────────────────────────────
    // Curva suave (Catmull-Rom) a partir de los valores, con los extremos
    // atenuados para que la onda nazca y muera en los bordes.
    function curve(samplesPerValue: int): var {
        const values = Array.from(root.values ?? []);
        const n = values.length;
        if (n < 2) return [];
        const out = [];
        const total = (n - 1) * samplesPerValue;
        for (let k = 0; k <= total; k++) {
            const f = k / samplesPerValue;
            const i = Math.floor(f);
            const t = f - i;
            const p0 = values[Math.max(0, i - 1)];
            const p1 = values[i];
            const p2 = values[Math.min(n - 1, i + 1)];
            const p3 = values[Math.min(n - 1, i + 2)];
            const v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t);
            const x = k / total;
            out.push({ x, v: Math.max(0, Math.min(1, v)) * Math.pow(Math.sin(Math.PI * x), 0.6) });
        }
        return out;
    }

    Shape {
        id: waveLayer
        anchors.fill: parent
        // Triangula el relleno en un hilo aparte, no en el de la interfaz.
        asynchronous: true
        opacity: root.style === "wave" || root.style === "mirror" || root.style === "line" ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        readonly property bool isMirror: root.style === "mirror"
        readonly property bool filled: root.style !== "line"
        readonly property real centerLine: isMirror ? height / 2 + (height - root.maxHeight) / 2 - 4 : height - 4
        readonly property real reach: isMirror ? root.maxHeight / 2 : root.maxHeight
        // PathPolyline no acepta una lista vacía: se usa un punto suelto.
        readonly property var empty: [Qt.point(0, height)]

        // Bordes calculados UNA vez por cuadro y compartidos por el relleno y
        // las líneas (antes se recalculaban 2–4 veces cada uno).
        readonly property var edges: {
            if (!visible) return { upper: empty, lower: empty };
            const points = root.curve(3);
            if (points.length === 0) return { upper: empty, lower: empty };
            const upper = new Array(points.length);
            const lower = isMirror ? new Array(points.length) : null;
            for (let k = 0; k < points.length; k++) {
                const px = points[k].x * width;
                const dv = points[k].v * reach;
                upper[k] = Qt.point(px, centerLine - dv);
                if (lower) lower[k] = Qt.point(px, centerLine + dv);
            }
            return { upper, lower: lower ?? empty };
        }

        // Relleno
        ShapePath {
            strokeColor: "transparent"
            fillGradient: root.rainbow ? rainbowFill : verticalFill

            PathPolyline {
                path: {
                    if (!waveLayer.filled) return waveLayer.empty;
                    const top = waveLayer.edges.upper;
                    if (waveLayer.isMirror) return top.concat(waveLayer.edges.lower.slice().reverse());
                    return top.concat([Qt.point(waveLayer.width, waveLayer.height), Qt.point(0, waveLayer.height)]);
                }
            }
        }

        // Línea de la cresta
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.rainbow ? Qt.alpha("white", 0.85) : Qt.lighter(root.color, 1.4)
            strokeWidth: root.lineWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline { path: waveLayer.edges.upper }
        }

        // En espejo, también la línea de abajo
        ShapePath {
            fillColor: "transparent"
            strokeColor: !waveLayer.isMirror ? "transparent" : root.rainbow ? Qt.alpha("white", 0.85) : Qt.lighter(root.color, 1.4)
            strokeWidth: root.lineWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline { path: waveLayer.isMirror ? waveLayer.edges.lower : waveLayer.empty }
        }

        LinearGradient {
            id: verticalFill
            x1: 0
            y1: waveLayer.centerLine - waveLayer.reach
            x2: 0
            y2: waveLayer.isMirror ? waveLayer.centerLine + waveLayer.reach : waveLayer.centerLine
            GradientStop { position: 0; color: Qt.alpha(Qt.lighter(root.color, 1.2), 0.75) }
            GradientStop { position: waveLayer.isMirror ? 0.5 : 1; color: Qt.alpha(root.color, waveLayer.isMirror ? 0.35 : 0.08) }
            GradientStop { position: 1; color: Qt.alpha(Qt.lighter(root.color, 1.2), waveLayer.isMirror ? 0.75 : 0.08) }
        }

        LinearGradient {
            id: rainbowFill
            x1: 0; y1: 0; x2: waveLayer.width; y2: 0
            GradientStop { position: 0.0; color: Qt.alpha(Qt.hsva(0.75, 0.55, 1, 1), 0.55) }
            GradientStop { position: 0.25; color: Qt.alpha(Qt.hsva(0.56, 0.55, 1, 1), 0.55) }
            GradientStop { position: 0.5; color: Qt.alpha(Qt.hsva(0.38, 0.55, 1, 1), 0.55) }
            GradientStop { position: 0.75; color: Qt.alpha(Qt.hsva(0.18, 0.55, 1, 1), 0.55) }
            GradientStop { position: 1.0; color: Qt.alpha(Qt.hsva(0.0, 0.55, 1, 1), 0.55) }
        }
    }
}
