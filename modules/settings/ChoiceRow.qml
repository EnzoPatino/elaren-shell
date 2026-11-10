pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"

// Fila con selector segmentado: [{ value, label, icon? }]. El fondo del
// elegido se desliza entre opciones.
RowBase {
    id: root

    property list<var> options: []
    property var current
    signal chosen(var value)

    readonly property int currentIndex: options.findIndex(o => o.value === current)

    Rectangle {
        width: row.implicitWidth + 8
        height: 34
        radius: 17
        color: Qt.alpha(Theme.text, 0.06)

        Rectangle {
            id: highlight
            // itemAt() no avisa cuando se crean los botones: se recalcula
            // también al cambiar la cantidad y el ancho de la fila.
            readonly property Item target: {
                repeater.count;
                row.implicitWidth;
                return repeater.itemAt(Math.max(0, root.currentIndex));
            }
            x: (target?.x ?? 0) + 4
            y: 4
            width: target?.width ?? 0
            height: parent.height - 8
            radius: height / 2
            color: Theme.primary
            opacity: root.currentIndex >= 0 ? 1 : 0

            Behavior on x { Anim { easing.bezierCurve: Theme.anim.expressive } }
            Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressive } }
        }

        Row {
            id: row
            x: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: repeater
                model: root.options

                Item {
                    id: option
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.currentIndex

                    width: content.implicitWidth + 24
                    height: 26

                    Row {
                        id: content
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!option.modelData.icon
                            text: option.modelData.icon ?? ""
                            font.pixelSize: 15
                            color: option.selected ? Theme.textOnPrimary : Theme.textMuted
                            animateChange: false
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: option.modelData.label
                            font.pixelSize: Theme.font.small + 1
                            font.weight: option.selected ? Font.Bold : Font.Medium
                            color: option.selected ? Theme.textOnPrimary : Theme.text
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chosen(option.modelData.value)
                    }
                }
            }
        }
    }
}
