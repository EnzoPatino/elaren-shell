pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../config"
import "../../services"

// Contenido de la isla desplegada: pestañas arriba y la vista elegida abajo.
// La forma de vidrio la dibuja la barra; esto es solo lo de adentro.
//
// Las vistas viven en un Loader que solo está activo mientras la isla se ve:
// cerrada, no queda ni el visualizador ni la búsqueda de letra trabajando.
Item {
    id: root

    property bool active: false
    // "home" | "music" | "system" | "tray" | "calendar"
    property string tab: "home"
    // Ventana de la barra: los menús de la bandeja se abren sobre ella.
    property var barWindow
    property real lookX: 0
    property real lookY: 0

    signal closeRequested()

    // Pestañas activas según Configuración → Barra (Música, además, solo con
    // un reproductor disponible).
    readonly property var tabs: [
        { id: "home", label: "Inicio", icon: "home", on: true },
        { id: "music", label: "Música", icon: "album", on: Config.barTabMusic && Media.available },
        { id: "system", label: "Recursos", icon: "monitor_heart", on: Config.barTabSystem },
        { id: "tray", label: "Bandeja", icon: "apps", on: Config.barTabTray },
        { id: "calendar", label: "Calendario", icon: "calendar_month", on: Config.barTabCalendar }
    ].filter(t => t.on)

    readonly property bool mediaTab: tab === "music"

    // Si la pestaña elegida deja de estar (se apagó, o se cerró el
    // reproductor), se vuelve a Inicio: nunca queda una vista vacía.
    function ensureTab(): void {
        if (!tabs.some(t => t.id === tab)) tab = "home";
    }
    onTabsChanged: ensureTab()
    onTabChanged: ensureTab()

    implicitWidth: Math.max(tabRow.implicitWidth + closeButton.width + Theme.spacing.normal, view.implicitWidth) + Theme.spacing.large * 2
    implicitHeight: Theme.spacing.large + tabRow.height + Theme.spacing.normal + view.implicitHeight + Theme.spacing.large

    // ── Pestañas ──────────────────────────────────────────────────────────
    Row {
        id: tabRow

        x: Theme.spacing.large
        y: Theme.spacing.large
        height: 32
        spacing: Theme.spacing.small

        Repeater {
            model: root.tabs

            Rectangle {
                id: tabButton

                required property var modelData
                readonly property bool current: root.tab === modelData.id

                width: tabContent.implicitWidth + 24
                height: 32
                radius: Theme.radius.full
                color: current ? Qt.alpha(Theme.primary, 0.2) : Qt.alpha(Theme.text, 0.05)
                border.width: 1
                border.color: current ? Qt.alpha(Theme.primary, 0.45) : "transparent"

                Behavior on color { CAnim {} }
                Behavior on border.color { CAnim {} }

                Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabButton.modelData.icon
                        font.pixelSize: 16
                        color: tabButton.current ? Theme.primary : Theme.textMuted
                        animateChange: false
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabButton.modelData.label
                        color: tabButton.current ? Theme.text : Theme.textMuted
                        font.weight: tabButton.current ? Font.DemiBold : Font.Medium
                    }
                }

                StateLayer {
                    radius: Theme.radius.full
                    onClicked: root.tab = tabButton.modelData.id
                }
            }
        }
    }

    // Volver a la barra
    Rectangle {
        id: closeButton

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.large
        y: Theme.spacing.large
        width: 32
        height: 32
        radius: 16
        color: Qt.alpha(Theme.text, 0.05)

        MaterialIcon {
            anchors.centerIn: parent
            text: "expand_less"
            font.pixelSize: 20
            color: Theme.textMuted
            animateChange: false
        }

        StateLayer {
            radius: 16
            onClicked: root.closeRequested()
        }
    }

    // ── Vista ─────────────────────────────────────────────────────────────
    Loader {
        id: view

        x: (root.width - width) / 2
        y: tabRow.y + tabRow.height + Theme.spacing.normal
        active: root.active
        sourceComponent: root.tab === "calendar" ? calendarView : root.tab === "system" ? systemView : root.tab === "tray" ? trayView : root.mediaTab ? musicView : homeView

        // Cambio de vista: entra con un leve fundido.
        onLoaded: if (item) fadeIn.restart()
        NumberAnimation { id: fadeIn; target: view; property: "opacity"; from: 0; to: 1; duration: Theme.anim.normal }
    }

    Component {
        id: homeView
        HomeView {
            lookX: root.lookX
            lookY: root.lookY
        }
    }

    Component {
        id: musicView
        NowPlayingView {
            onDismissed: root.closeRequested()
        }
    }

    Component {
        id: calendarView
        CalendarView {}
    }

    Component {
        id: trayView
        TrayView {
            barWindow: root.barWindow
        }
    }

    Component {
        id: systemView
        SystemView {
            onDismissed: root.closeRequested()
        }
    }
}
