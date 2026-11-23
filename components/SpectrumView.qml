pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../theme"

// Dibuja un espectro de audio con distintos estilos. No calcula nada: recibe
// los valores (0..1) ya suavizados. Lo usan el visualizador de escritorio y
// las vistas previas del panel de Configuración.
//
// Estilos:
//   "wave"   onda rellena
//   "mirror" onda espejada
//   "silk"   tres cintas translúcidas que se cruzan y ondulan
//   "stems"  líneas finas con un punto en la punta (con tapitas: el punto
//            queda arriba y cae despacio)
//   "pills"  píldoras que crecen desde el centro hacia los dos lados
//
// Solo la capa del estilo elegido trabaja: las demás no leen los valores.
Item {
    id: root

    // Arrays de JS (no `list<real>`): cada barra indexa estos valores en cada
    // cuadro, y una `list<real>` se copia entera en cada acceso.
    property var values: []
    property var caps: []
    property string style: "wave"
    // "cover"/"accent" usan `color`; "rainbow" pinta un arcoíris.
    property string colorMode: "accent"
    property color color: Theme.primary
    property real maxHeight: height - 12
    property real barWidth: 0.62     // fracción del hueco de cada píldora
    property bool showCaps: true
    property real lineWidth: 2.5
    // Segundos, para lo que se mueve aunque el espectro no cambie (la seda
    // ondula). Visualizer.clock o el reloj de la demostración.
    property real time: 0

    readonly property int count: values?.length ?? 0
    readonly property bool rainbow: colorMode === "rainbow"

    function colorAt(fraction: real): color {
        return rainbow ? Qt.hsva(0.75 - fraction * 0.75, 0.55, 1, 1) : root.color;
    }

    // ── Curva suave ───────────────────────────────────────────────────────
    // Catmull-Rom a partir de los valores, con los extremos atenuados para
    // que la onda nazca y muera en los bordes.
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

    // ── wave / mirror ─────────────────────────────────────────────────────
    Shape {
        id: waveLayer
        anchors.fill: parent
        // Sin `asynchronous`: la curva cambia en cada cuadro y la triangulación
        // en otro hilo se pisaba con la siguiente y tiraba abajo Quickshell
        // (segfault en QtQuickShapes). Son pocas decenas de puntos; en el hilo
        // de la interfaz no se nota.
        opacity: root.style === "wave" || root.style === "mirror" ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        readonly property bool isMirror: root.style === "mirror"
        readonly property real centerLine: isMirror ? height / 2 + (height - root.maxHeight) / 2 - 4 : height - 4
        readonly property real reach: isMirror ? root.maxHeight / 2 : root.maxHeight
        // PathPolyline no acepta una lista vacía: se usa un punto suelto.
        readonly property var empty: [Qt.point(0, height)]

        // Bordes calculados UNA vez por cuadro y compartidos por el relleno y
        // las líneas.
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

    // ── silk ──────────────────────────────────────────────────────────────
    // Tres cintas sobre una línea central. Cada una sigue el espectro, pero
    // modulado por una onda lenta que viaja (con `time`): por eso se cruzan.
    // El borde de abajo de cada cinta es un eco más chico del de arriba.
    Shape {
        id: silkLayer
        anchors.fill: parent
        opacity: root.style === "silk" ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        readonly property real centerLine: height - 4 - root.maxHeight / 2
        readonly property real reach: root.maxHeight / 2
        readonly property var empty: [Qt.point(0, centerLine)]
        // [fase, amplitud, velocidad] de cada cinta
        readonly property var ribbons: [[0, 1.0, 1.0], [2.1, 0.85, 1.45], [4.2, 0.7, 1.9]]

        readonly property var paths: {
            if (!visible) return [{ fill: empty, edge: empty }, { fill: empty, edge: empty }, { fill: empty, edge: empty }];
            const points = root.curve(2);
            const t = root.time;
            return ribbons.map(([phase, amp, speed]) => {
                if (points.length === 0) return { fill: empty, edge: empty };
                const top = new Array(points.length);
                const bottom = new Array(points.length);
                for (let k = 0; k < points.length; k++) {
                    const p = points[k];
                    const d = p.v * reach * amp * Math.sin(p.x * Math.PI * 3 + t * speed + phase);
                    const px = p.x * width;
                    top[k] = Qt.point(px, centerLine - d);
                    bottom[points.length - 1 - k] = Qt.point(px, centerLine + d * 0.35);
                }
                return { fill: top.concat(bottom), edge: top };
            });
        }

        // Relleno de cada cinta y, encima, su borde.
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.alpha(root.colorAt(0 / 2), 0.34)
            PathPolyline { path: silkLayer.paths[0].fill }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.alpha(root.colorAt(1 / 2), 0.26)
            PathPolyline { path: silkLayer.paths[1].fill }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.alpha(root.colorAt(2 / 2), 0.18)
            PathPolyline { path: silkLayer.paths[2].fill }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Qt.lighter(root.colorAt(0 / 2), 1.3), 0.8)
            strokeWidth: Math.max(1, root.lineWidth * 0.6)
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: silkLayer.paths[0].edge }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Qt.lighter(root.colorAt(1 / 2), 1.3), 0.8)
            strokeWidth: Math.max(1, root.lineWidth * 0.6)
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: silkLayer.paths[1].edge }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Qt.lighter(root.colorAt(2 / 2), 1.3), 0.8)
            strokeWidth: Math.max(1, root.lineWidth * 0.6)
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: silkLayer.paths[2].edge }
        }
    }

    // ── stems / pills ─────────────────────────────────────────────────────
    Item {
        id: barsLayer
        anchors.fill: parent
        opacity: root.style === "stems" || root.style === "pills" ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        readonly property bool pills: root.style === "pills"
        readonly property real slot: width / Math.max(1, root.count)
        readonly property real thickness: Math.max(3, slot * root.barWidth)
        readonly property real centerLine: height - 4 - root.maxHeight / 2

        Repeater {
            model: barsLayer.visible ? root.count : 0

            Item {
                id: bar

                required property int index
                readonly property real value: Math.min(1, root.values[index] ?? 0)
                readonly property real cap: root.showCaps ? Math.max(value, Math.min(1, root.caps[index] ?? 0)) : value
                readonly property color tint: root.colorAt(index / Math.max(1, root.count - 1))

                x: index * barsLayer.slot
                width: barsLayer.slot
                height: parent.height

                // Tallo: 2 px que se desvanecen hacia abajo
                Rectangle {
                    visible: !barsLayer.pills
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: 2
                    height: root.maxHeight * bar.value
                    radius: 1
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(bar.tint, 0.9) }
                        GradientStop { position: 1; color: Qt.alpha(bar.tint, 0) }
                    }
                }

                // Punto en la punta (con tapitas, queda arriba y cae despacio)
                Rectangle {
                    visible: !barsLayer.pills
                    readonly property real size: 5 + 3 * bar.value
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 4 - root.maxHeight * bar.cap - size / 2
                    width: size
                    height: size
                    radius: size / 2
                    color: Qt.lighter(bar.tint, 1.25)
                }

                // Píldora centrada
                Rectangle {
                    visible: barsLayer.pills
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: barsLayer.thickness
                    height: Math.max(width, root.maxHeight * bar.value)
                    y: barsLayer.centerLine - height / 2
                    radius: width / 2
                    color: bar.tint
                    opacity: 0.55 + 0.45 * bar.value
                }
            }
        }
    }
}
