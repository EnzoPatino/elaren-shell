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
    // Pegada al borde superior (no flotante): solo los costados tienen margen
    // y las esquinas de abajo van redondeadas.
    implicitHeight: Theme.bar.height - Theme.bar.margin
    color: "transparent"
    WlrLayershell.namespace: "elaren-bar"

    // Desenfoque real (KWin) detrás de la barra: el vidrio deja ver el fondo.
    BackgroundEffect.blurRegion: Region {
        item: background
        bottomLeftRadius: background.bottomLeftRadius
        bottomRightRadius: background.bottomRightRadius
    }

    property bool revealed: false

    // Popup abierto ("calendar", "system" o ""). Solo uno a la vez.
    property string activePopup: ""

    function togglePopup(name: string): void {
        activePopup = activePopup === name ? "" : name;
    }

    // Un tic de retardo para que los Behavior ya estén activos.
    Timer {
        interval: 60
        running: true
        onTriggered: bar.revealed = true
    }

    StyledRect {
        id: background

        anchors.fill: parent
        anchors.leftMargin: Theme.bar.margin
        anchors.rightMargin: Theme.bar.margin
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.radius.large
        bottomRightRadius: Theme.radius.large
        color: Theme.glass
        border.color: Theme.glassBorder
        border.width: 1

        // Brillo inferior: un filo de luz que marca el borde de la barra
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: parent.bottomLeftRadius - 1
            bottomRightRadius: parent.bottomRightRadius - 1
            gradient: Gradient {
                GradientStop { position: 0.4; color: "transparent" }
                GradientStop { position: 1; color: Theme.glassHighlight }
            }
        }

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

            LauncherButton {
                anchors.verticalCenter: parent.verticalCenter
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

            ActiveWindow {
                anchors.verticalCenter: parent.verticalCenter
                revealed: bar.revealed
                revealDelay: 160
                maxWidth: Math.min(320, bar.width * 0.17)
            }
        }

        // ── Centro ────────────────────────────────────────────────────────
        Clock {
            id: clock
            anchors.centerIn: parent
            revealed: bar.revealed
            revealDelay: 200
            calendarOpen: bar.activePopup === "calendar"
            onClicked: bar.togglePopup("calendar")
        }

        // ── Derecha ───────────────────────────────────────────────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.small + 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.normal

            SystemWidget {
                id: system
                revealed: bar.revealed
                revealDelay: 230
                popupOpen: bar.activePopup === "system"
                onClicked: bar.togglePopup("system")
            }

            MediaWidget {
                id: media
                anchors.verticalCenter: parent.verticalCenter
                revealed: bar.revealed
                revealDelay: 260
                popupOpen: bar.activePopup === "media"
                onPopupRequested: bar.togglePopup("media")
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
        open: bar.activePopup === "calendar"
        onDismissed: if (bar.activePopup === "calendar") bar.activePopup = ""
    }

    SystemPopup {
        anchorItem: system
        open: bar.activePopup === "system"
        onDismissed: if (bar.activePopup === "system") bar.activePopup = ""
    }

    NowPlayingPopup {
        anchorItem: media
        open: bar.activePopup === "media" && Media.available
        onDismissed: if (bar.activePopup === "media") bar.activePopup = ""
    }
}
