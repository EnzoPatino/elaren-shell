pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Escritorios virtuales de KWin.
// - Activo: píldora ancha con su rótulo.
// - Con ventanas: rótulo. Vacío: un punto (que muestra el rótulo al pasar el ratón).
// - Rótulos (Config.barWorkspaceStyle): números (1 2 3), romanos (I II III),
//   kanji (一 二 三), solo puntos (los ocupados más grandes) o "pacman": el
//   activo es un pacman, los que tienen ventanas son fantasmas y los vacíos,
//   pellets. Al cambiar de escritorio el pacman viaja comiendo y los
//   fantasmas lo siguen con la mirada (solo anima durante el viaje).
//   Al cambiar de estilo los rótulos dan un giro escalonado.
// - El indicador se desplaza con efecto "gusano": el borde delantero va
//   rápido y el trasero lo alcanza después.
Item {
    id: root

    readonly property int cellSize: 22
    readonly property int activeWidth: 34
    readonly property int gap: 2
    readonly property int active: Workspaces.activeIndex
    readonly property int count: Workspaces.list.length

    readonly property string style: ["numbers", "roman", "kanji", "dots", "pacman"].includes(Config.barWorkspaceStyle)
        ? Config.barWorkspaceStyle : "numbers"

    function roman(n: int): string {
        const table = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        for (const [value, glyph] of table) {
            while (n >= value) {
                out += glyph;
                n -= value;
            }
        }
        return out;
    }

    function kanji(n: int): string {
        const digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
        if (n < 10) return digits[n];
        const tens = Math.floor(n / 10);
        return (tens > 1 ? digits[tens] : "") + "十" + digits[n % 10];
    }

    function label(index: int): string {
        const n = index + 1;
        return style === "roman" ? roman(n) : style === "kanji" ? kanji(n)
            : style === "dots" || style === "pacman" ? "" : String(n);
    }

    // Los romanos largos (VIII) necesitan más lugar que un dígito.
    function cellWidth(index: int): int {
        if (style === "pacman") return index === active ? 26 : cellSize;
        const extra = style === "roman" ? Math.max(0, label(index).length - 2) * 7 : 0;
        return (index === active ? activeWidth : cellSize) + extra;
    }

    // Borde izquierdo de una celda según los anchos *finales* (no los animados).
    function cellX(index: int): real {
        let x = 0;
        for (let i = 0; i < index; i++) x += cellWidth(i) + gap;
        return x;
    }

    implicitWidth: Math.max(cellSize, cellX(count) - gap)
    implicitHeight: cellSize

    Behavior on implicitWidth { Anim {} }

    function moveIndicator(index: int): void {
        if (index < 0) return;
        const left = cellX(index);
        const right = left + cellWidth(index);
        const forward = left > indicator.leadEdge;
        leftAnim.duration = forward ? Theme.anim.slow : Theme.anim.normal;
        rightAnim.duration = forward ? Theme.anim.normal : Theme.anim.slow;
        indicator.leadEdge = left;
        indicator.tailEdge = right;

        // El pacman viaja comiendo hasta el centro del escritorio nuevo.
        const target = left + cellWidth(index) / 2;
        if (style !== "pacman" || !pacReady || Math.abs(target - pacX) < 1 || Theme.anim.scale <= 0) {
            travel.stop();
            pacX = target;
            pacReady = true;
            return;
        }
        pacman.facingLeft = target < pacX;
        travel.to = target;
        travel.duration = Math.max(260, Math.abs(target - pacX) * 7) * Theme.anim.scale;
        travel.restart();
    }

    // ── Pacman ────────────────────────────────────────────────────────────
    property real pacX: 0
    property bool pacReady: false
    readonly property var ghostColors: ["#ff4d6d", "#ffa1d6", "#4fd6ff", "#ffb347"]

    NumberAnimation {
        id: travel
        target: root
        property: "pacX"
        easing.type: Easing.InOutSine
    }

    // Mastica solo mientras viaja; después vuelve a su boca de reposo.
    SequentialAnimation {
        id: chomp
        running: travel.running
        loops: Animation.Infinite
        NumberAnimation { target: pacman; property: "mouth"; to: 3; duration: 95 }
        NumberAnimation { target: pacman; property: "mouth"; to: 44; duration: 95 }
        onRunningChanged: if (!running) settle.restart()
    }
    NumberAnimation { id: settle; target: pacman; property: "mouth"; to: 35; duration: 160; easing.type: Easing.OutBack }

    onActiveChanged: moveIndicator(active)
    onCountChanged: moveIndicator(active)
    onStyleChanged: {
        moveIndicator(active);
        flip.restart();
    }

    // Giro escalonado de los rótulos al cambiar de estilo (0 → 1)
    property real flipProgress: 1
    NumberAnimation {
        id: flip
        target: root
        property: "flipProgress"
        from: 0
        to: 1
        duration: Theme.anim.extraSlow + root.count * 40 * Theme.anim.scale
    }
    Component.onCompleted: moveIndicator(active)

    Rectangle {
        id: indicator

        property real leadEdge: 0
        property real tailEdge: root.activeWidth

        x: leadEdge
        width: tailEdge - leadEdge
        height: root.cellSize
        radius: Theme.radius.full
        opacity: root.active >= 0 && root.style !== "pacman" ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.primary }
            GradientStop { position: 1; color: Qt.lighter(Theme.primary, 1.12) }
        }

        Behavior on leadEdge { Anim { id: leftAnim; easing.bezierCurve: Theme.anim.emphasizedDecel } }
        Behavior on tailEdge { Anim { id: rightAnim; easing.bezierCurve: Theme.anim.emphasizedDecel } }
        Behavior on opacity { Anim {} }
    }

    Row {
        spacing: root.gap

        Repeater {
            model: Workspaces.list

            Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool isActive: index === root.active
                readonly property bool occupied: KWin.windowsOn(modelData.id).length > 0
                readonly property bool showNumber: root.style !== "dots" && root.style !== "pacman"
                    && (isActive || occupied || touch.containsMouse)
                readonly property bool pac: root.style === "pacman"
                // Tramo propio del giro (escalonado de izquierda a derecha)
                readonly property real flipT: {
                    const total = 1 + root.count * 0.12;
                    return Math.max(0, Math.min(1, root.flipProgress * total - index * 0.12));
                }

                width: root.cellWidth(index)
                height: root.cellSize

                Behavior on width { Anim { easing.bezierCurve: Theme.anim.emphasizedDecel } }

                StyledText {
                    anchors.centerIn: parent
                    text: root.label(cell.index)
                    font.pixelSize: root.style === "kanji" ? Theme.font.small + 1 : Theme.font.small
                    font.weight: cell.isActive ? Font.Bold : Font.DemiBold
                    color: cell.isActive ? Theme.textOnPrimary : cell.occupied ? Theme.text : Theme.textMuted
                    font.letterSpacing: root.style === "roman" ? -0.5 : 0
                    opacity: cell.showNumber ? 1 : 0
                    scale: cell.showNumber ? 1 : 0.5
                    // Giro sobre el eje horizontal al cambiar de estilo
                    transform: Rotation {
                        origin.x: 0
                        origin.y: 7
                        axis { x: 1; y: 0; z: 0 }
                        angle: (1 - cell.flipT) * 90
                    }

                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                // Estilo "puntos": en el activo, un punto dentro de la píldora
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.style === "dots"
                    width: cell.isActive ? 14 : 0
                    height: 4
                    radius: 2
                    color: Theme.textOnPrimary
                    opacity: cell.isActive ? 0.9 : 0

                    Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                }

                // Punto para los escritorios vacíos
                Rectangle {
                    // En "puntos", los escritorios con ventanas llevan un punto
                    // más grande y claro; el activo no lleva (va su píldora).
                    readonly property bool big: root.style === "dots" && cell.occupied
                    anchors.centerIn: parent
                    width: big ? 7 : 5
                    height: width
                    radius: width / 2
                    // En "pacman" son pellets
                    color: big ? Theme.text : cell.pac ? "#f6c99b" : Theme.textMuted
                    readonly property bool hidden: cell.showNumber || (root.style === "dots" && cell.isActive)
                        || (cell.pac && (cell.isActive || cell.occupied))
                    opacity: hidden ? 0 : big ? 0.85 : cell.pac ? 0.9 : 0.55
                    scale: hidden ? 0 : (1 + (1 - cell.flipT) * 0.6) * (cell.pac && touch.containsMouse ? 1.5 : 1)

                    Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }

                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                // Fantasma en los escritorios con ventanas (estilo pacman);
                // mira hacia donde está el pacman.
                Ghost {
                    readonly property bool shown: cell.pac && cell.occupied && !cell.isActive
                    anchors.centerIn: parent
                    width: 14
                    height: 15
                    color: root.ghostColors[cell.index % root.ghostColors.length]
                    look: Math.max(-1, Math.min(1, (root.pacX - (cell.x + cell.width / 2)) / 12))
                    opacity: shown ? 1 : 0
                    scale: shown ? cell.flipT * (touch.containsMouse ? 1.15 : 1) : 0.3
                    visible: opacity > 0.01

                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.full
                    onClicked: Workspaces.activate(cell.index)
                }
            }
        }
    }

    Pacman {
        id: pacman
        x: root.pacX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        opacity: root.style === "pacman" && root.active >= 0 ? 1 : 0
        scale: root.style === "pacman" ? root.flipProgress : 0.3
        visible: opacity > 0.01

        Behavior on opacity { Anim {} }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Workspaces.cycle(event.angleDelta.y > 0 ? -1 : 1)
    }
}
