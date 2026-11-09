import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// Barra superior. Al arrancar (y en cada recarga en caliente) cae desde
// arriba y sus grupos aparecen escalonados de izquierda a derecha.
PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.bar.height
    color: "transparent"
    WlrLayershell.namespace: "elaren-bar"

    property bool revealed: false

    // Un tic de retardo para que los Behavior ya estén activos.
    Timer {
        interval: 60
        running: true
        onTriggered: bar.revealed = true
    }

    StyledRect {
        id: background

        anchors.fill: parent
        anchors.topMargin: Theme.bar.margin
        anchors.leftMargin: Theme.bar.margin
        anchors.rightMargin: Theme.bar.margin
        radius: Theme.radius.large
        color: Theme.surface
        border.color: Qt.alpha(Theme.outline, 0.6)
        border.width: 1

        opacity: bar.revealed ? 1 : 0
        transform: Translate {
            y: bar.revealed ? 0 : -Theme.bar.height
            Behavior on y { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.expressive } }
        }
        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        // ── Izquierda ─────────────────────────────────────────────────────
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.small + 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.normal

            Launcher {
                revealed: bar.revealed
            }

            Reveal {
                anchors.verticalCenter: parent.verticalCenter
                shown: Workspaces.list.length > 0

                BarGroup {
                    padding: 3
                    revealed: bar.revealed
                    revealDelay: 120

                    WorkspacesWidget {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── Centro ────────────────────────────────────────────────────────
        Clock {
            id: clock
            anchors.centerIn: parent
            revealed: bar.revealed
            revealDelay: 200
        }

        // ── Derecha ───────────────────────────────────────────────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.small + 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.normal

            MediaWidget {
                anchors.verticalCenter: parent.verticalCenter
                revealed: bar.revealed
                revealDelay: 260
            }

            Tray {
                anchors.verticalCenter: parent.verticalCenter
                barWindow: bar
                revealed: bar.revealed
                revealDelay: 320
            }

            BarGroup {
                revealed: bar.revealed
                revealDelay: 380

                VolumeWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }

                BatteryWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    CalendarPopup {
        anchorItem: clock
        open: clock.calendarOpen
        onDismissed: clock.calendarOpen = false
    }
}
