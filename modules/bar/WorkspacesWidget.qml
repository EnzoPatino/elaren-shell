pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Escritorios virtuales (KWin) o espacios de trabajo (Hyprland).
// Estilos (Config.barWorkspaceStyle):
// - "numbers": el activo es una píldora ancha con su número; los que tienen
//   ventanas muestran el número con una marquita abajo y los vacíos, un
//   punto (que muestra el número al pasar el ratón).
// - "pills": solo formas. El activo es una píldora larga de acento; los
//   ocupados, píldoras claras; los vacíos, cortas y tenues.
// - "orbit": anillos unidos por un hilo. Ocupados rellenos, vacíos huecos;
//   un halo de acento recorre el hilo hasta el activo.
// - "apps": el ícono de las apps abiertas en cada escritorio (hasta tres).
// El indicador se desplaza con efecto "gusano": el borde delantero va rápido
// y el trasero lo alcanza después. Al cambiar de estilo las celdas entran
// escalonadas.
Item {
    id: root

    readonly property int cellSize: 22
    readonly property int active: Workspaces.activeIndex
    readonly property int count: Workspaces.list.length

    readonly property var styles: ["numbers", "pills", "orbit", "apps"]
    // Estilos que ya no existen pasan al más parecido.
    readonly property string style: {
        const s = Config.barWorkspaceStyle;
        if (styles.includes(s)) return s;
        return s === "dots" || s === "pacman" ? "pills" : "numbers";
    }

    readonly property int gap: style === "numbers" || style === "apps" ? 2 : 4
    readonly property int maxIcons: 3
    readonly property int iconSize: 16

    // Número del escritorio: el id real en Hyprland (puede haber huecos, p. ej.
    // 1…5 y 9), la posición en KWin (sus ids no son números).
    function number(index: int): int {
        const id = Number(Workspaces.list[index]?.id);
        return Number.isInteger(id) && id > 0 ? id : index + 1;
    }

    // Apps distintas abiertas en un escritorio (sin las de "todos los escritorios").
    function appsOn(index: int): list<string> {
        const ws = Workspaces.list[index];
        if (!ws) return [];
        const ids = [];
        for (const w of Compositor.windowsOn(ws.id)) {
            if (w.onAllDesktops || !w.appId || ids.includes(w.appId)) continue;
            ids.push(w.appId);
        }
        return ids;
    }

    function occupied(index: int): bool {
        const ws = Workspaces.list[index];
        return ws ? Compositor.windowsOn(ws.id).length > 0 : false;
    }

    function cellWidth(index: int): int {
        const isActive = index === active;
        switch (style) {
        case "pills": return isActive ? 28 : 12;
        case "orbit": return 18;
        case "apps": {
            const n = Math.min(maxIcons, appsOn(index).length);
            return n === 0 ? (isActive ? 30 : cellSize) : n * (iconSize + 2) + (isActive ? 14 : 6);
        }
        default: return isActive ? 34 : cellSize;
        }
    }

    // Borde izquierdo de una celda según los anchos *finales* (no los animados).
    function cellX(index: int): real {
        let x = 0;
        for (let i = 0; i < index; i++) x += cellWidth(i) + gap;
        return x;
    }

    implicitWidth: Math.max(cellSize, cellX(count) - gap)
    implicitHeight: cellSize

    Behavior on implicitWidth { Anim { easing.bezierCurve: Theme.anim.emphasizedDecel } }

    function moveIndicator(index: int): void {
        if (index < 0) return;
        const left = cellX(index);
        const right = left + cellWidth(index);
        const forward = left > indicator.leadEdge;
        leftAnim.duration = forward ? Theme.anim.slow : Theme.anim.normal;
        rightAnim.duration = forward ? Theme.anim.normal : Theme.anim.slow;
        indicator.leadEdge = left;
        indicator.tailEdge = right;
    }

    onActiveChanged: moveIndicator(active)
    onCountChanged: moveIndicator(active)
    onStyleChanged: {
        moveIndicator(active);
        intro.restart();
    }
    // Las apps de un escritorio cambian su ancho: reacomodar el indicador.
    Connections {
        target: Compositor
        enabled: root.style === "apps"
        function onWindowsChanged(): void { Qt.callLater(root.moveIndicator, root.active); }
    }

    // Entrada escalonada al cambiar de estilo (0 → 1)
    property real introProgress: 1
    NumberAnimation {
        id: intro
        target: root
        property: "introProgress"
        from: 0
        to: 1
        duration: Theme.anim.extraSlow + root.count * 40 * Theme.anim.scale
    }
    Component.onCompleted: moveIndicator(active)

    // ── Hilo de la órbita ─────────────────────────────────────────────────
    Rectangle {
        visible: root.style === "orbit" && root.count > 1
        x: 9
        width: Math.max(0, root.implicitWidth - 18)
        height: 2
        radius: 1
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.textMuted
        opacity: 0.25 * root.introProgress
    }

    // ── Indicador del activo ──────────────────────────────────────────────
    Rectangle {
        id: indicator

        property real leadEdge: 0
        property real tailEdge: 34

        x: leadEdge
        width: tailEdge - leadEdge
        height: root.style === "pills" ? 8 : root.style === "orbit" ? 18 : root.cellSize
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.radius.full
        opacity: root.active >= 0 ? 1 : 0

        // Píldora llena (números, píldoras); anillo con halo (órbita);
        // vidrio de acento para que se lean los íconos (apps).
        readonly property bool solid: root.style === "numbers" || root.style === "pills"
        color: root.style === "orbit" ? Qt.alpha(Theme.primary, 0.22)
            : root.style === "apps" ? Qt.alpha(Theme.primary, 0.28) : Theme.primary
        gradient: solid ? fill : null
        border.width: solid ? 0 : root.style === "orbit" ? 2 : 1
        border.color: Theme.primary

        Gradient {
            id: fill
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.primary }
            GradientStop { position: 1; color: Qt.lighter(Theme.primary, 1.12) }
        }

        // Halo suave alrededor del anillo de la órbita
        Rectangle {
            visible: root.style === "orbit"
            anchors.centerIn: parent
            width: parent.width + 8
            height: parent.height + 8
            radius: height / 2
            color: "transparent"
            border.width: 3
            border.color: Qt.alpha(Theme.primary, 0.18)
        }

        Behavior on leadEdge { Anim { id: leftAnim; easing.bezierCurve: Theme.anim.emphasizedDecel } }
        Behavior on tailEdge { Anim { id: rightAnim; easing.bezierCurve: Theme.anim.emphasizedDecel } }
        Behavior on height { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
        Behavior on opacity { Anim {} }
    }

    Row {
        spacing: root.gap

        Behavior on spacing { Anim {} }

        Repeater {
            model: Workspaces.list

            Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool isActive: index === root.active
                readonly property bool occupied: Compositor.windowsOn(modelData.id).length > 0
                readonly property bool hovered: touch.containsMouse
                // Tramo propio de la entrada (escalonada de izquierda a derecha)
                readonly property real introT: {
                    const total = 1 + root.count * 0.12;
                    return Math.max(0, Math.min(1, root.introProgress * total - index * 0.12));
                }

                width: root.cellWidth(index)
                height: root.cellSize

                Behavior on width { Anim { easing.bezierCurve: Theme.anim.emphasizedDecel } }

                // ── Números ───────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.style === "numbers"
                    scale: 0.6 + 0.4 * cell.introT
                    opacity: cell.introT

                    readonly property bool showNumber: cell.isActive || cell.occupied || cell.hovered

                    StyledText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: cell.occupied && !cell.isActive ? -1 : 0
                        rotation: Theme.bar.upright
                        text: String(root.number(cell.index))
                        font.pixelSize: Theme.font.small
                        font.weight: cell.isActive ? Font.Bold : Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: cell.isActive ? Theme.textOnPrimary : cell.occupied ? Theme.text : Theme.textMuted
                        opacity: parent.showNumber ? 1 : 0
                        scale: parent.showNumber ? 1 : 0.5

                        Behavior on opacity { Anim { duration: Theme.anim.fast } }
                        Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                        Behavior on anchors.verticalCenterOffset { Anim { duration: Theme.anim.fast } }
                    }

                    // Marquita de "tiene ventanas"
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: cell.occupied && !cell.isActive ? 6 : 0
                        height: 2
                        radius: 1
                        color: Theme.primary
                        opacity: 0.8

                        Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                    }

                    // Punto de los vacíos
                    Rectangle {
                        readonly property bool hidden: parent.showNumber
                        anchors.centerIn: parent
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Theme.textMuted
                        opacity: hidden ? 0 : 0.55
                        scale: hidden ? 0 : 1

                        Behavior on opacity { Anim { duration: Theme.anim.fast } }
                        Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                    }
                }

                // ── Píldoras ──────────────────────────────────────────────
                Rectangle {
                    visible: root.style === "pills"
                    anchors.centerIn: parent
                    width: cell.isActive ? parent.width : cell.hovered ? 12 : cell.occupied ? 10 : 6
                    height: cell.isActive ? 8 : cell.occupied ? 6 : 6
                    radius: height / 2
                    color: cell.occupied ? Theme.text : Theme.textMuted
                    opacity: (cell.isActive ? 0 : cell.occupied ? 0.85 : 0.4) * cell.introT
                    scale: 0.4 + 0.6 * cell.introT

                    Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                }

                // ── Órbita ────────────────────────────────────────────────
                Rectangle {
                    visible: root.style === "orbit"
                    anchors.centerIn: parent
                    property real size: cell.isActive ? 8 : cell.hovered ? 10 : 8
                    width: size
                    height: size
                    radius: size / 2
                    // Ocupados rellenos; vacíos, un anillo hueco sobre el hilo.
                    color: cell.isActive ? Theme.primary : cell.occupied ? Theme.text : Theme.surface
                    border.width: cell.occupied || cell.isActive ? 0 : 1.5
                    border.color: Theme.textMuted
                    opacity: (cell.occupied || cell.isActive ? 1 : 0.75) * cell.introT
                    scale: cell.introT

                    Behavior on size { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                    Behavior on color { CAnim { duration: Theme.anim.fast } }
                }

                // ── Apps ──────────────────────────────────────────────────
                Item {
                    id: appsCell
                    anchors.fill: parent
                    visible: root.style === "apps"

                    readonly property var apps: visible ? root.appsOn(cell.index).slice(0, root.maxIcons) : []

                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: appsCell.apps

                            Image {
                                required property string modelData
                                required property int index
                                width: root.iconSize
                                height: root.iconSize
                                sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                                source: Apps.icon(modelData)
                                rotation: Theme.bar.upright
                                smooth: true
                                asynchronous: true
                                opacity: cell.isActive || cell.hovered ? 1 : 0.7
                                scale: Math.max(0, Math.min(1, cell.introT * 1.6 - index * 0.2))

                                Behavior on opacity { Anim { duration: Theme.anim.fast } }
                            }
                        }
                    }

                    // Escritorio sin apps: su número, chico
                    StyledText {
                        anchors.centerIn: parent
                        visible: appsCell.apps.length === 0
                        rotation: Theme.bar.upright
                        text: String(root.number(cell.index))
                        font.pixelSize: Theme.font.small
                        font.weight: cell.isActive ? Font.Bold : Font.DemiBold
                        color: cell.isActive ? Theme.text : Theme.textMuted
                        opacity: (cell.isActive || cell.hovered ? 1 : 0.6) * cell.introT
                    }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.full
                    onClicked: Workspaces.activate(cell.index)
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Workspaces.cycle(event.angleDelta.y > 0 ? -1 : 1)
    }
}
