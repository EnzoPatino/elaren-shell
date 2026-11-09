pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../theme"
import "../../components"

// Bandeja del sistema (StatusNotifierItem). Cada icono entra con un rebote.
Reveal {
    id: root

    required property var barWindow
    property bool revealed: true
    property int revealDelay: 0

    shown: SystemTray.items.values.length > 0 && revealed

    BarGroup {
        padding: Theme.spacing.small
        revealed: root.revealed
        revealDelay: root.revealDelay

        Repeater {
            model: SystemTray.items

            Item {
                id: entry

                required property SystemTrayItem modelData

                anchors.verticalCenter: parent?.verticalCenter
                width: 24
                height: 24

                Anim on scale { from: 0; to: 1; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: entry.modelData.icon
                    scale: touch.pressed ? 0.8 : touch.containsMouse ? 1.15 : 1

                    Behavior on scale { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.full
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: event => {
                        const item = entry.modelData;
                        if (event.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (event.button === Qt.RightButton || item.onlyMenu) {
                            if (!item.hasMenu) return;
                            const pos = entry.mapToItem(null, 0, entry.height);
                            item.display(root.barWindow, pos.x, pos.y + Theme.spacing.normal);
                        } else {
                            item.activate();
                        }
                    }

                    onWheel: event => entry.modelData.scroll(event.angleDelta.y, false)
                }
            }
        }
    }
}
