pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Escritorios virtuales de KWin.
// - Activo: píldora ancha con su número.
// - Con ventanas: número. Vacío: un punto (que muestra el número al pasar el ratón).
// - El indicador se desplaza con efecto "gusano": el borde delantero va
//   rápido y el trasero lo alcanza después.
Item {
    id: root

    readonly property int cellSize: 22
    readonly property int activeWidth: 34
    readonly property int gap: 2
    readonly property int active: Workspaces.activeIndex
    readonly property int count: Workspaces.list.length

    function cellWidth(index: int): int {
        return index === active ? activeWidth : cellSize;
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
        const right = left + activeWidth;
        const forward = left > indicator.leadEdge;
        leftAnim.duration = forward ? Theme.anim.slow : Theme.anim.normal;
        rightAnim.duration = forward ? Theme.anim.normal : Theme.anim.slow;
        indicator.leadEdge = left;
        indicator.tailEdge = right;
    }

    onActiveChanged: moveIndicator(active)
    onCountChanged: moveIndicator(active)
    Component.onCompleted: moveIndicator(active)

    Rectangle {
        id: indicator

        property real leadEdge: 0
        property real tailEdge: root.activeWidth

        x: leadEdge
        width: tailEdge - leadEdge
        height: root.cellSize
        radius: Theme.radius.full
        opacity: root.active >= 0 ? 1 : 0
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
                readonly property bool showNumber: isActive || occupied || touch.containsMouse

                width: root.cellWidth(index)
                height: root.cellSize

                Behavior on width { Anim { easing.bezierCurve: Theme.anim.emphasizedDecel } }

                StyledText {
                    anchors.centerIn: parent
                    text: cell.index + 1
                    font.pixelSize: Theme.font.small
                    font.weight: cell.isActive ? Font.Bold : Font.DemiBold
                    color: cell.isActive ? Theme.textOnPrimary : cell.occupied ? Theme.text : Theme.textMuted
                    opacity: cell.showNumber ? 1 : 0
                    scale: cell.showNumber ? 1 : 0.5

                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                // Punto para los escritorios vacíos
                Rectangle {
                    anchors.centerIn: parent
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Theme.textMuted
                    opacity: cell.showNumber ? 0 : 0.55
                    scale: cell.showNumber ? 0 : 1

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

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Workspaces.cycle(event.angleDelta.y > 0 ? -1 : 1)
    }
}
