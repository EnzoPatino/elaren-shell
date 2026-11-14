pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../theme"
import "../../components"

// Vista "Bandeja" de la isla: las apps de la bandeja del sistema
// (StatusNotifierItem) como fichas con ícono y nombre.
// Clic: activar · Derecho: menú · Medio: acción secundaria · Rueda: desplazar.
Item {
    id: root

    // Ventana sobre la que se abren los menús de las apps.
    required property var barWindow

    readonly property int columns: 3
    readonly property int cellWidth: 150

    implicitWidth: columns * cellWidth + (columns - 1) * Theme.spacing.normal
    implicitHeight: SystemTray.items.values.length > 0 ? grid.implicitHeight : empty.implicitHeight + 40

    Grid {
        id: grid
        columns: root.columns
        spacing: Theme.spacing.normal

        Repeater {
            model: SystemTray.items

            Rectangle {
                id: entry

                required property SystemTrayItem modelData

                width: root.cellWidth
                height: 44
                radius: Theme.radius.normal
                color: Qt.alpha(Theme.text, touch.containsMouse ? 0.09 : 0.05)

                Behavior on color { CAnim {} }

                Anim on scale { from: 0.6; to: 1; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing.large
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.normal

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 20
                        source: entry.modelData.icon
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20 - parent.spacing
                        text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                    }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.normal
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: event => {
                        const item = entry.modelData;
                        if (event.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (event.button === Qt.RightButton || item.onlyMenu) {
                            if (!item.hasMenu) return;
                            const pos = entry.mapToItem(null, 0, entry.height);
                            item.display(root.barWindow, pos.x, pos.y + Theme.spacing.small);
                        } else {
                            item.activate();
                        }
                    }

                    onWheel: event => entry.modelData.scroll(event.angleDelta.y, false)
                }
            }
        }
    }

    Column {
        id: empty
        anchors.centerIn: parent
        spacing: Theme.spacing.small
        visible: SystemTray.items.values.length === 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "inbox"
            font.pixelSize: 30
            color: Theme.textMuted
            animateChange: false
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No hay apps en la bandeja"
            color: Theme.textMuted
        }
    }
}
