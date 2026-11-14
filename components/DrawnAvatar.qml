pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../theme"

// Personaje pseudo-3D generado a partir de una semilla (un texto): la misma
// semilla siempre da el mismo personaje. Inspirado en Bible Strong Avatar Lab
// (github.com/smontlouis/bible-strong-avatar-lab, motor MIT), reescrito acá
// en QML: el cuerpo es un sólido 3D (esfera, cubo redondeado, cápsula, gota…)
// que se rota de verdad y se proyecta con perspectiva; su contorno es la
// envolvente de los puntos proyectados. La cara (ojos, boca, nariz) está
// pegada a la superficie: se achata al girar y se oculta de espaldas. Las
// orejas, antenas, etc. son piezas con su propia profundidad.
//
// Movimiento:
// - Mirada: gira la cabeza hacia `lookX` / `lookY` (-1..1) con un suavizado
//   exponencial.
// - Parpadeo cada pocos segundos.
// - `idle`: respira y se balancea (solo donde se ve grande: en la barra no,
//   para no redibujarla todo el tiempo).
// - Gestos con `play("spin" | "nod" | "bounce")`.
// Cuando no hay nada que animar, el bucle de cuadros se detiene.
Item {
    id: root

    property string seed: "elaren"
    property real lookX: 0
    property real lookY: 0
    property bool animated: true
    property bool idle: false

    implicitWidth: 64
    implicitHeight: 64

    readonly property real s: Math.min(width, height)
    readonly property bool canAnimate: animated && visible && Theme.anim.scale > 0

    // ── Rasgos a partir de la semilla ─────────────────────────────────────
    readonly property var traits: {
        // FNV-1a + mulberry32: "al azar" pero repetible.
        let h = 2166136261;
        for (let i = 0; i < seed.length; i++) h = Math.imul(h ^ seed.charCodeAt(i), 16777619);
        let a = h >>> 0;
        function next() {
            a = (a + 0x6D2B79F5) | 0;
            let t = Math.imul(a ^ (a >>> 15), 1 | a);
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        }
        function pick(list) { return list[Math.floor(next() * list.length)]; }

        const bodies = [
            { kind: "sphere", a: 1, b: 1, c: 1, e1: 1, e2: 1, taper: 0 },
            { kind: "cube", a: 0.9, b: 0.9, c: 0.9, e1: 0.32, e2: 0.32, taper: 0 },
            { kind: "capsule", a: 0.78, b: 1.12, c: 0.78, e1: 0.55, e2: 1, taper: 0 },
            { kind: "drop", a: 1, b: 1.02, c: 1, e1: 1, e2: 1, taper: 0.32 },
            { kind: "bean", a: 1.12, b: 0.86, c: 0.95, e1: 0.8, e2: 1, taper: 0 },
            { kind: "can", a: 0.86, b: 1.02, c: 0.86, e1: 0.25, e2: 1, taper: 0 }
        ];
        const colors = ["#a6c8ff", "#cdb4ff", "#f5a9c9", "#a6e3c4", "#fab387", "#f9e2af", "#f38ba8", "#89dceb", "#b4befe", "#94e2d5"];
        const eyes = [[0.15, 0.24], [0.19, 0.19], [0.11, 0.28], [0.24, 0.13], [0.16, 0.16]];
        const color = pick(colors);
        const eye = pick(eyes);
        return {
            body: pick(bodies),
            color: color,
            outline: Qt.darker(color, 1.55),
            eyeColor: "#1c1b22",
            eyeW: eye[0],
            eyeH: eye[1],
            eyeRound: next() < 0.6,
            eyeSpread: 0.26 + next() * 0.12,
            eyeTilt: (next() - 0.5) * 16,
            mouth: pick(["curve", "curve", "curve", "ellipse", "flat", "smile", "none"]),
            nose: next() < 0.3,
            blush: next() < 0.4,
            extra: pick(["none", "none", "ears", "bunny", "antenna", "tuft", "horns"])
        };
    }

    // Puntos de la superficie (sin rotar), se recalculan solo al cambiar los
    // rasgos. Superelipsoide: e1/e2 = 1 es una esfera; valores chicos, un cubo.
    function surfacePoint(body: var, theta: real, phi: real): var {
        function f(w, e) { return Math.sign(w) * Math.pow(Math.abs(w), e); }
        const cp = Math.cos(phi), sp = Math.sin(phi);
        let x = body.a * f(cp, body.e1) * f(Math.sin(theta), body.e2);
        const y = body.b * f(sp, body.e1);
        let z = body.c * f(cp, body.e1) * f(Math.cos(theta), body.e2);
        if (body.taper > 0) {
            // Gota: más angosta arriba (y negativo es arriba).
            const t = (y / body.b + 1) / 2;
            const k = 1 - body.taper + body.taper * t;
            x *= k;
            z *= k;
        }
        return [x, y, z];
    }

    readonly property var samples: {
        const out = [];
        const body = traits.body;
        for (let i = 0; i < 36; i++)
            for (let j = 1; j < 18; j++)
                out.push(surfacePoint(body, i / 36 * 2 * Math.PI, -Math.PI / 2 + j / 18 * Math.PI));
        out.push(surfacePoint(body, 0, -Math.PI / 2), surfacePoint(body, 0, Math.PI / 2));
        return out;
    }

    // ── Estado de la pose ─────────────────────────────────────────────────
    // Se integra cuadro a cuadro en un objeto JS (`motion`) y se publica una
    // sola vez por cuadro en `pose`: así la proyección se recalcula una vez y
    // no por cada propiedad que cambia.
    readonly property var motion: ({ yaw: 0, pitch: 0, shiftX: 0, shiftY: 0, clock: 0, gesture: "", gestureTime: 0 })
    property var pose: ({ yaw: 0, pitch: 0, shiftX: 0, shiftY: 0, clock: 0, gesture: "", gestureTime: 0 })
    property real blink: 1

    function gestureLength(name: string): real {
        return name === "spin" ? 0.95 : name === "nod" ? 0.5 : name === "bounce" ? 0.62 : 0;
    }

    function publish(): void {
        pose = Object.assign({}, motion);
    }

    // Sin animaciones: la pose salta directo a donde mira.
    function snap(): void {
        motion.yaw = targetYaw;
        motion.pitch = targetPitch;
        motion.shiftX = 0.05 * lookX;
        motion.shiftY = 0.04 * lookY;
        motion.gesture = "";
        publish();
    }

    Component.onCompleted: canAnimate ? loop.running = true : snap()

    function play(name: string): void {
        if (!canAnimate) return;
        motion.gesture = name;
        motion.gestureTime = 0;
        loop.running = true;
    }

    // Mirada pedida (grados / unidades), como en el original: 18° a los lados
    // y 14° arriba/abajo.
    readonly property real targetYaw: 18 * lookX
    readonly property real targetPitch: 14 * lookY
    onTargetYawChanged: canAnimate ? loop.running = true : snap()
    onTargetPitchChanged: canAnimate ? loop.running = true : snap()
    onIdleChanged: if (canAnimate) loop.running = true
    onCanAnimateChanged: canAnimate ? loop.running = true : snap()

    FrameAnimation {
        id: loop
        running: false
        onTriggered: {
            const st = root.motion;
            const dt = Math.min(0.1, frameTime);
            const share = 1 - Math.pow(1 - 0.14, dt * 60);
            st.yaw += (root.targetYaw - st.yaw) * share;
            st.pitch += (root.targetPitch - st.pitch) * share;
            st.shiftX += (0.05 * root.lookX - st.shiftX) * share;
            st.shiftY += (0.04 * root.lookY - st.shiftY) * share;
            st.clock += dt;
            if (st.gesture !== "") {
                st.gestureTime += dt;
                if (st.gestureTime >= root.gestureLength(st.gesture)) st.gesture = "";
            }
            root.publish();
            const settled = Math.abs(root.targetYaw - st.yaw) < 0.05 && Math.abs(root.targetPitch - st.pitch) < 0.05;
            if (!root.canAnimate || (settled && !root.idle && st.gesture === "")) running = false;
        }
    }

    // Parpadeo
    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "blink"; to: 0.08; duration: 70 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 120 }
    }

    Timer {
        running: root.canAnimate
        repeat: true
        interval: 3000
        onTriggered: {
            interval = 2400 + Math.random() * 3800;
            blinkAnim.restart();
        }
    }

    // ── Proyección ────────────────────────────────────────────────────────
    readonly property var frame: {
        const s = root.s;
        const k = s * 0.31;
        const focal = 5.2;
        const cx = s / 2, cy = s * 0.55;
        const ps = pose;
        const g = ps.gesture, len = gestureLength(g), p = len > 0 ? Math.min(1, ps.gestureTime / len) : 0;
        const clock = ps.clock, shiftX = ps.shiftX, shiftY = ps.shiftY;

        let yawDeg = ps.yaw, pitchDeg = ps.pitch, lift = 0, sx = 1, sy = 1;
        if (idle) {
            yawDeg += 7 * Math.sin(clock * 0.55);
            pitchDeg += 4 * Math.sin(clock * 0.42 + 1);
            lift += 0.025 * Math.sin(clock * 1.7);
            sy *= 1 + 0.018 * Math.sin(clock * 1.7);
        }
        if (g === "spin") {
            const e = p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
            yawDeg += 360 * e;
        } else if (g === "nod") {
            pitchDeg += 16 * Math.pow(Math.sin(Math.PI * p), 2);
        } else if (g === "bounce") {
            const w = Math.sin(2 * Math.PI * p) * (1 - p);
            sy *= 1 - 0.14 * w;
            sx *= 1 + 0.1 * w;
            lift -= 0.32 * Math.sin(Math.PI * p);
        }

        const ya = yawDeg * Math.PI / 180, pa = pitchDeg * Math.PI / 180;
        const cyw = Math.cos(ya), syw = Math.sin(ya), cpt = Math.cos(pa), spt = Math.sin(pa);
        function rotate(v) {
            // Escala (rebote), giro sobre Y y después sobre X.
            const x0 = v[0] * sx, y0 = v[1] * sy, z0 = v[2] * sx;
            const x1 = x0 * cyw + z0 * syw, z1 = -x0 * syw + z0 * cyw;
            const y2 = y0 * cpt - z1 * spt, z2 = y0 * spt + z1 * cpt;
            return [x1, y2, z2];
        }
        function project(v) {
            const w = focal / (focal - v[2]);
            return { x: cx + (v[0] + shiftX) * k * w, y: cy + (v[1] + shiftY + lift) * k * w, w: w, z: v[2] };
        }

        // Contorno: envolvente convexa (cadena monótona) de los puntos.
        const pts = samples.map(v => project(rotate(v))).sort((a, b) => a.x - b.x || a.y - b.y);
        function cross(o, a, b) { return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x); }
        const lower = [], upper = [];
        for (const pt of pts) {
            while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], pt) <= 0) lower.pop();
            lower.push(pt);
        }
        for (let i = pts.length - 1; i >= 0; i--) {
            const pt = pts[i];
            while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], pt) <= 0) upper.pop();
            upper.push(pt);
        }
        const hull = lower.slice(0, -1).concat(upper.slice(0, -1)).map(q => Qt.point(q.x, q.y));
        if (hull.length > 0) hull.push(hull[0]);

        // Rasgos sobre la superficie: posición proyectada, escorzo y si se ven.
        const body = traits.body;
        function feature(theta, phi) {
            const local = surfacePoint(body, theta, phi);
            const len = Math.hypot(local[0], local[1], local[2]) || 1;
            const n = rotate([local[0] / len, local[1] / len, local[2] / len]);
            const q = project(rotate(local));
            return {
                x: q.x, y: q.y, w: q.w,
                fx: Math.max(0.12, Math.sqrt(Math.max(0, 1 - n[0] * n[0]))),
                fy: Math.max(0.12, Math.sqrt(Math.max(0, 1 - n[1] * n[1]))),
                visible: n[2] > 0.08
            };
        }
        const spread = traits.eyeSpread;
        // Piezas extra: centro proyectado y si quedan delante o detrás.
        function node(v) {
            const q = project(rotate(v));
            return { x: q.x, y: q.y, w: q.w, front: q.z > -0.05 };
        }
        const top = -body.b;
        // Luz desde arriba a la izquierda, pegada a la superficie: el brillo
        // se corre al girar y eso da el volumen.
        const light = project(rotate([-0.38, -0.5, 0.78]));
        const center = project(rotate([0, 0, 0]));
        return {
            hull: hull,
            light: light,
            center: center,
            k: k,
            roll: 0,
            eyeL: feature(-spread, -0.1),
            eyeR: feature(spread, -0.1),
            nose: feature(0, 0.12),
            mouthL: feature(-0.2, 0.3),
            mouthC: feature(0, 0.4),
            mouthR: feature(0.2, 0.3),
            cheekL: feature(-0.55, 0.22),
            cheekR: feature(0.55, 0.22),
            earL: node([-0.66 * body.a, top * 0.72, -0.05]),
            earR: node([0.66 * body.a, top * 0.72, -0.05]),
            bunnyL: node([-0.3 * body.a, top - 0.5, -0.05]),
            bunnyR: node([0.3 * body.a, top - 0.5, -0.05]),
            antennaBase: node([0, top + 0.05, 0]),
            antennaTip: node([0.18, top - 0.5, 0]),
            tuft: node([0, top - 0.08, 0.05]),
            hornL: node([-0.42 * body.a, top * 0.86, 0.1]),
            hornR: node([0.42 * body.a, top * 0.86, 0.1])
        };
    }

    readonly property real stroke: Math.max(1, s * 0.022)

    // ── Piezas detrás del cuerpo ──────────────────────────────────────────
    Extras { front: false }

    // ── Cuerpo ────────────────────────────────────────────────────────────
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.traits.color
            strokeColor: root.traits.outline
            strokeWidth: root.stroke
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.frame.hull }
        }

        // Sombra hacia el borde
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.frame.center.x; centerY: root.frame.center.y
                focalX: root.frame.light.x; focalY: root.frame.light.y
                centerRadius: root.frame.k * 1.15
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha("black", 0.22) }
            }
            PathPolyline { path: root.frame.hull }
        }

        // Brillo
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.frame.light.x; centerY: root.frame.light.y
                focalX: centerX; focalY: centerY
                centerRadius: root.frame.k * 0.62
                GradientStop { position: 0; color: Qt.alpha("white", 0.42) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathPolyline { path: root.frame.hull }
        }
    }

    // ── Piezas delante del cuerpo ─────────────────────────────────────────
    Extras { front: true }

    // ── Cara ──────────────────────────────────────────────────────────────
    Repeater {
        model: root.traits.blush ? [root.frame.cheekL, root.frame.cheekR] : []
        Rectangle {
            required property var modelData
            visible: modelData.visible
            width: root.frame.k * 0.26 * modelData.w * modelData.fx
            height: root.frame.k * 0.14 * modelData.w * modelData.fy
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            radius: height / 2
            color: Qt.alpha("#ff6b8a", 0.35)
        }
    }

    Repeater {
        model: [root.frame.eyeL, root.frame.eyeR]
        Rectangle {
            id: eye
            required property var modelData
            required property int index
            visible: modelData.visible
            width: root.frame.k * root.traits.eyeW * modelData.w * modelData.fx
            height: Math.max(1, root.frame.k * root.traits.eyeH * modelData.w * modelData.fy * root.blink)
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            radius: root.traits.eyeRound ? Math.min(width, height) / 2 : Math.min(width, height) * 0.3
            rotation: index === 0 ? root.traits.eyeTilt : -root.traits.eyeTilt
            color: root.traits.eyeColor
        }
    }

    Rectangle {
        readonly property var f: root.frame.nose
        visible: root.traits.nose && f.visible
        width: root.frame.k * 0.12 * f.w * f.fx
        height: root.frame.k * 0.08 * f.w * f.fy
        x: f.x - width / 2
        y: f.y - height / 2
        radius: height / 2
        color: root.traits.outline
    }

    Shape {
        anchors.fill: parent
        visible: root.traits.mouth !== "none" && root.frame.mouthC.visible
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            readonly property var l: root.frame.mouthL
            readonly property var c: root.frame.mouthC
            readonly property var r: root.frame.mouthR
            readonly property bool filled: root.traits.mouth === "ellipse" || root.traits.mouth === "smile"

            strokeColor: filled ? "transparent" : root.traits.eyeColor
            strokeWidth: root.stroke * 1.2
            fillColor: filled ? "#5b1f2b" : "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: {
                    const l = root.frame.mouthL, c = root.frame.mouthC, r = root.frame.mouthR;
                    switch (root.traits.mouth) {
                    case "ellipse": {
                        const rx = root.frame.k * 0.07 * c.w * c.fx, ry = root.frame.k * 0.09 * c.w * c.fy;
                        return `M ${c.x - rx} ${c.y - ry * 0.4} a ${rx} ${ry} 0 1 0 ${2 * rx} 0 a ${rx} ${ry} 0 1 0 ${-2 * rx} 0 Z`;
                    }
                    case "flat": return `M ${l.x} ${(l.y + c.y) / 2} L ${r.x} ${(r.y + c.y) / 2}`;
                    case "smile": return `M ${l.x} ${l.y} Q ${c.x} ${c.y + (c.y - l.y) * 1.4} ${r.x} ${r.y} Z`;
                    default: return `M ${l.x} ${l.y} Q ${c.x} ${c.y + (c.y - l.y)} ${r.x} ${r.y}`;
                    }
                }
            }
        }
    }

    // Orejas, antenas, cuernos… Se dibujan dos veces: las que quedan detrás
    // del cuerpo antes, las de adelante después.
    component Extras: Item {
        id: extras

        property bool front: false

        anchors.fill: parent

        // Orejas redondas
        Repeater {
            model: root.traits.extra === "ears" ? [root.frame.earL, root.frame.earR] : []
            Rectangle {
                required property var modelData
                visible: modelData.front === extras.front
                width: root.frame.k * 0.68 * modelData.w
                height: width
                x: modelData.x - width / 2
                y: modelData.y - height / 2
                radius: width / 2
                color: root.traits.color
                border.width: root.stroke
                border.color: root.traits.outline
            }
        }

        // Orejas de conejo
        Repeater {
            model: root.traits.extra === "bunny" ? [root.frame.bunnyL, root.frame.bunnyR] : []
            Rectangle {
                required property var modelData
                required property int index
                visible: modelData.front === extras.front
                width: root.frame.k * 0.34 * modelData.w
                height: root.frame.k * 1.05 * modelData.w
                x: modelData.x - width / 2
                y: modelData.y - height / 2
                radius: width / 2
                rotation: index === 0 ? -10 : 10
                color: root.traits.color
                border.width: root.stroke
                border.color: root.traits.outline

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: parent.height * 0.7
                    radius: width / 2
                    color: Qt.alpha("#ff8fab", 0.55)
                }
            }
        }

        // Cuernitos
        Repeater {
            model: root.traits.extra === "horns" ? [root.frame.hornL, root.frame.hornR] : []
            Rectangle {
                required property var modelData
                required property int index
                visible: modelData.front === extras.front
                width: root.frame.k * 0.22 * modelData.w
                height: root.frame.k * 0.42 * modelData.w
                x: modelData.x - width / 2
                y: modelData.y - height * 0.85
                radius: width / 2
                rotation: index === 0 ? -18 : 18
                color: Qt.lighter(root.traits.outline, 1.4)
                border.width: root.stroke
                border.color: root.traits.outline
            }
        }

        // Antena: palito y bolita
        Shape {
            anchors.fill: parent
            visible: root.traits.extra === "antenna" && root.frame.antennaTip.front === extras.front
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.traits.outline
                strokeWidth: root.stroke * 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathPolyline {
                    path: [Qt.point(root.frame.antennaBase.x, root.frame.antennaBase.y), Qt.point(root.frame.antennaTip.x, root.frame.antennaTip.y)]
                }
            }
        }

        Rectangle {
            readonly property var f: root.frame.antennaTip
            visible: root.traits.extra === "antenna" && f.front === extras.front
            width: root.frame.k * 0.26 * f.w
            height: width
            x: f.x - width / 2
            y: f.y - height / 2
            radius: width / 2
            color: Theme.warning
            border.width: root.stroke
            border.color: root.traits.outline
        }

        // Mechón arriba
        Rectangle {
            readonly property var f: root.frame.tuft
            visible: root.traits.extra === "tuft" && f.front === extras.front
            width: root.frame.k * 0.3 * f.w
            height: root.frame.k * 0.36 * f.w
            x: f.x - width / 2
            y: f.y - height
            radius: width / 2
            rotation: 20
            color: Qt.darker(root.traits.color, 1.2)
            border.width: root.stroke
            border.color: root.traits.outline
        }
    }
}
