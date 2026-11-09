pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Escritorios virtuales. El indicador activo se desplaza con efecto
// "gusano": el borde delantero va rápido y el trasero lo alcanza después.
Item {
    id: root

    readonly property int cellSize: 22
    readonly property int gap: 4
    readonly property int active: Workspaces.activeIndex

    implicitWidth: Math.max(cellSize, Workspaces.list.length * (cellSize + gap) - gap)
    implicitHeight: cellSize

    function moveIndicator(index: int): void {
        if (index < 0) return;
        const left = index * (cellSize + gap);
        const right = left + cellSize;
        const forward = left > indicator.leadEdge;
        leftAnim.duration = forward ? Theme.anim.slow : Theme.anim.normal;
        rightAnim.duration = forward ? Theme.anim.normal : Theme.anim.slow;
        indicator.leadEdge = left;
        indicator.tailEdge = right;
    }

    onActiveChanged: moveIndicator(active)
    Component.onCompleted: moveIndicator(active)

    Rectangle {
        id: indicator

        property real leadEdge: 0
        property real tailEdge: root.cellSize

        x: leadEdge
        width: tailEdge - leadEdge
        height: root.cellSize
        radius: Theme.radius.full
        color: Theme.primary
        opacity: root.active >= 0 ? 1 : 0

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

                width: root.cellSize
                height: root.cellSize

                StyledText {
                    anchors.centerIn: parent
                    text: cell.modelData.name || (cell.index + 1)
                    font.pixelSize: Theme.font.small
                    font.weight: cell.isActive ? Font.Bold : Font.Medium
                    color: cell.isActive ? Theme.textOnPrimary : cell.modelData.urgent ? Theme.error : Theme.textMuted
                    scale: cell.isActive ? 1.1 : 1

                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                StateLayer {
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
