pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Lanzador de aplicaciones a pantalla completa.
//
// - Buscador arriba (se escribe directamente al abrir).
// - Secciones a la izquierda: Todas, Frecuentes, Juegos, Internet…
// - Teclado: flechas para moverse, Enter abre, Tab/Shift+Tab cambia de
//   sección, Esc borra la búsqueda o cierra.
PanelWindow {
    id: root

    property string section: "all"
    property string query: ""
    readonly property bool searching: query.trim().length > 0
    readonly property list<var> results: searching ? AppLauncher.search(query) : AppLauncher.appsIn(section)
    readonly property var currentSection: AppLauncher.sections.find(s => s.id === section) ?? AppLauncher.sections[0]

    property real progress: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: progress > 0.001
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "elaren-launcher"
    WlrLayershell.keyboardFocus: AppLauncher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    function selectSection(id: string): void {
        query = "";
        search.text = "";
        section = id;
        grid.currentIndex = 0;
    }

    function stepSection(step: int): void {
        const list = AppLauncher.sections;
        const i = list.findIndex(s => s.id === section);
        selectSection(list[(i + step + list.length) % list.length].id);
    }

    Connections {
        target: AppLauncher
        function onOpenChanged() {
            progressAnim.easing.bezierCurve = AppLauncher.open ? Theme.anim.expressive : Theme.anim.emphasizedAccel;
            progressAnim.duration = AppLauncher.open ? Theme.anim.slow : Theme.anim.normal;
            root.progress = AppLauncher.open ? 1 : 0;
            if (AppLauncher.open) {
                root.selectSection("all");
                search.forceActiveFocus();
            }
        }
    }

    Behavior on progress { Anim { id: progressAnim } }

    // Fondo oscurecido; clic fuera del panel cierra.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4 * Math.min(1, root.progress)

        MouseArea {
            anchors.fill: parent
            onClicked: AppLauncher.hide()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1000, parent.width - 80)
        height: Math.min(660, parent.height - 120)
        radius: 28
        color: Qt.alpha(Theme.surface, 0.93)
        border.color: Qt.alpha("white", 0.08)
        border.width: 1
        clip: true

        opacity: Math.min(1, root.progress)
        scale: 0.9 + 0.1 * root.progress
        transform: Translate { y: 40 * (1 - root.progress) }

        // Brillo sutil en la parte superior
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.07) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        // Evita que un clic en el panel llegue al fondo y lo cierre.
        MouseArea { anchors.fill: parent }

        // ── Barra lateral ─────────────────────────────────────────────────
        Item {
            id: sidebar

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 18
            width: 210

            // Usuario
            Row {
                id: user
                spacing: 12

                ClippingAvatar {
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText {
                        text: `Hola, ${Quickshell.env("USER")}`
                        font.pixelSize: Theme.font.large
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: `${AppLauncher.apps.length} aplicaciones`
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                    }
                }
            }

            // Abre el panel de Configuración de Elaren
            Rectangle {
                id: settingsButton
                anchors.right: parent.right
                anchors.verticalCenter: user.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: Qt.alpha(Theme.text, 0.06)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "settings"
                    color: settingsTouch.containsMouse ? Theme.primary : Theme.textMuted
                    animateChange: false
                    rotation: settingsTouch.containsMouse ? 90 : 0

                    Behavior on rotation { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
                }

                StateLayer {
                    id: settingsTouch
                    radius: 17
                    onClicked: Settings.show("")
                }
            }

            ListView {
                id: sectionList

                anchors.top: user.bottom
                anchors.topMargin: 22
                anchors.bottom: power.top
                anchors.bottomMargin: 12
                width: parent.width
                spacing: 2
                clip: true
                interactive: contentHeight > height
                model: AppLauncher.sections
                currentIndex: root.searching ? -1 : AppLauncher.sections.findIndex(s => s.id === root.section)

                highlightFollowsCurrentItem: false
                highlight: Rectangle {
                    width: sectionList.width
                    height: 40
                    radius: Theme.radius.normal + 2
                    color: Qt.alpha(Theme.primary, 0.16)
                    y: sectionList.currentItem?.y ?? 0
                    opacity: sectionList.currentIndex >= 0 ? 1 : 0

                    Behavior on y { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
                    Behavior on opacity { Anim {} }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 2
                        color: Theme.primary
                    }
                }

                delegate: Item {
                    id: sectionItem

                    required property var modelData
                    required property int index
                    readonly property bool active: ListView.isCurrentItem

                    width: sectionList.width
                    height: 40

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        spacing: 12

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sectionItem.modelData.icon
                            color: sectionItem.active ? Theme.primary : Theme.textMuted
                            animateChange: false
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sectionItem.modelData.name
                            color: sectionItem.active ? Theme.text : Theme.textMuted
                            font.weight: sectionItem.active ? Font.DemiBold : Font.Normal
                        }
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: sectionItem.modelData.count
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                        opacity: 0.7
                    }

                    StateLayer {
                        radius: Theme.radius.normal + 2
                        onClicked: root.selectSection(sectionItem.modelData.id)
                    }
                }
            }

            PowerRow {
                id: power
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }

        Rectangle {
            id: divider
            anchors.left: sidebar.right
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18
            width: 1
            color: Qt.alpha(Theme.outline, 0.6)
        }

        // ── Contenido ─────────────────────────────────────────────────────
        Item {
            id: main

            anchors.left: divider.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18
            anchors.leftMargin: 18

            // Buscador
            Rectangle {
                id: searchBox

                width: parent.width
                height: 48
                radius: Theme.radius.full
                color: Qt.alpha(Theme.surfaceHigh, 0.7)
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Qt.alpha(Theme.primary, 0.7) : Qt.alpha("white", 0.06)

                Behavior on border.color { CAnim {} }

                MaterialIcon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.pixelSize: 22
                    color: search.activeFocus ? Theme.primary : Theme.textMuted
                    animateChange: false
                    rotation: root.searching ? 90 : 0

                    Behavior on rotation { Anim { easing.bezierCurve: Theme.anim.expressive } }
                }

                TextInput {
                    id: search

                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: clear.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Qt.alpha(Theme.primary, 0.4)
                    selectedTextColor: Theme.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.large + 1
                    clip: true
                    focus: true

                    onTextChanged: {
                        root.query = text;
                        grid.currentIndex = 0;
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Buscar aplicaciones…"
                        color: Theme.textMuted
                        font.pixelSize: search.font.pixelSize
                    }

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            if (search.text) search.text = "";
                            else AppLauncher.hide();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            AppLauncher.launch(root.results[Math.max(0, grid.currentIndex)]);
                            break;
                        case Qt.Key_Left: grid.moveCurrentIndexLeft(); break;
                        case Qt.Key_Right: grid.moveCurrentIndexRight(); break;
                        case Qt.Key_Up: grid.moveCurrentIndexUp(); break;
                        case Qt.Key_Down: grid.moveCurrentIndexDown(); break;
                        case Qt.Key_Tab: root.stepSection(1); break;
                        case Qt.Key_Backtab: root.stepSection(-1); break;
                        default: return;
                        }
                        event.accepted = true;
                    }
                }

                Rectangle {
                    id: clear
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 15
                    color: Qt.alpha(Theme.text, 0.08)
                    scale: search.text ? 1 : 0
                    opacity: scale

                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 16
                        animateChange: false
                    }

                    StateLayer {
                        onClicked: {
                            search.text = "";
                            search.forceActiveFocus();
                        }
                    }
                }
            }

            // Título de la sección / resultados
            Row {
                id: heading
                anchors.top: searchBox.bottom
                anchors.topMargin: 18
                x: 6
                spacing: 10

                StyledText {
                    anchors.baseline: parent.bottom
                    text: root.searching ? "Resultados" : (root.currentSection?.name ?? "")
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    animate: true
                }
                StyledText {
                    anchors.baseline: parent.bottom
                    text: `${root.results.length}`
                    color: Theme.textMuted
                    animate: true
                }
            }

            GridView {
                id: grid

                anchors.top: heading.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                readonly property int columns: Math.max(1, Math.floor(width / 126))
                cellWidth: Math.floor(width / columns)
                cellHeight: 124
                clip: true
                keyNavigationWraps: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: 0

                model: ScriptModel { values: [...root.results] }

                highlightFollowsCurrentItem: true
                highlightMoveDuration: Theme.anim.fast
                highlight: Rectangle {
                    radius: 20
                    color: Qt.alpha(Theme.primary, 0.13)
                    border.color: Qt.alpha(Theme.primary, 0.45)
                    border.width: 1
                }

                add: Transition {
                    SequentialAnimation {
                        PropertyAction { property: "opacity"; value: 0 }
                        PauseAnimation { duration: Math.max(0, Math.min(ViewTransition.index, 24)) * 14 * Theme.anim.scale }
                        ParallelAnimation {
                            Anim { property: "opacity"; to: 1 }
                            Anim { property: "scale"; from: 0.8; to: 1; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
                        }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        Anim { property: "opacity"; to: 0; duration: Theme.anim.fast }
                        Anim { property: "scale"; to: 0.85; duration: Theme.anim.fast }
                    }
                }
                displaced: Transition {
                    Anim { properties: "x,y"; duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel }
                    Anim { property: "opacity"; to: 1 }
                    Anim { property: "scale"; to: 1 }
                }

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Image {
                        id: appIcon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        width: 56
                        height: 56
                        sourceSize: Qt.size(112, 112)
                        source: Icons.source(tile.modelData.icon)
                        smooth: true
                        scale: touch.pressed ? 0.88 : touch.containsMouse ? 1.1 : 1

                        Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                    }

                    StyledText {
                        anchors.top: appIcon.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name
                        font.pixelSize: Theme.font.small + 1
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: tile.GridView.isCurrentItem ? Theme.text : Qt.alpha(Theme.text, 0.85)
                    }

                    MouseArea {
                        id: touch
                        anchors.fill: parent
                        anchors.margins: 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) grid.currentIndex = tile.index
                        onClicked: AppLauncher.launch(tile.modelData)
                    }
                }

                // Sin resultados
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    opacity: grid.count === 0 ? 1 : 0
                    scale: opacity > 0.5 ? 1 : 0.9
                    visible: opacity > 0

                    Behavior on opacity { Anim {} }
                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressive } }

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "search_off"
                        font.pixelSize: 48
                        color: Theme.textMuted
                        animateChange: false
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searching ? `Nada coincide con «${root.query.trim()}»` : "No hay aplicaciones aquí"
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ── Piezas internas ───────────────────────────────────────────────────

    // Foto de usuario (~/.face.icon o ~/.face) o, si no hay, un icono.
    component ClippingAvatar: ClippingRectangle {
        width: 44
        height: 44
        radius: 22
        color: Qt.alpha(Theme.primary, 0.18)

        MaterialIcon {
            anchors.centerIn: parent
            visible: face.status !== Image.Ready
            text: "person"
            font.pixelSize: 24
            color: Theme.primary
            animateChange: false
        }

        Image {
            id: face
            anchors.fill: parent
            source: `file://${Quickshell.env("HOME")}/.face.icon`
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(88, 88)
            asynchronous: true
            visible: status === Image.Ready
            onStatusChanged: if (status === Image.Error && !source.toString().endsWith("/.face")) source = `file://${Quickshell.env("HOME")}/.face`
        }
    }

    // Bloquear, cerrar sesión, reiniciar y apagar. Las acciones destructivas
    // piden un segundo clic de confirmación.
    component PowerRow: Row {
        id: powerRow

        property string armed: ""

        spacing: 6

        Timer {
            id: disarm
            interval: 3000
            onTriggered: powerRow.armed = ""
        }

        Repeater {
            model: [
                { id: "lock", icon: "lock", label: "Bloquear", confirm: false },
                { id: "logout", icon: "logout", label: "¿Salir?", confirm: true },
                { id: "reboot", icon: "restart_alt", label: "¿Reiniciar?", confirm: true },
                { id: "poweroff", icon: "power_settings_new", label: "¿Apagar?", confirm: true }
            ]

            Rectangle {
                id: powerButton

                required property var modelData
                readonly property bool isArmed: powerRow.armed === modelData.id

                height: 40
                width: isArmed ? powerRow.width - 3 * (40 + powerRow.spacing) : 40
                radius: 20
                color: isArmed ? Theme.error : Qt.alpha(Theme.surfaceHigh, 0.8)
                clip: true

                Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressive } }
                Behavior on color { CAnim {} }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: powerButton.modelData.icon
                        color: powerButton.isArmed ? Theme.surface : Theme.textMuted
                        animateChange: false
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: powerButton.isArmed
                        text: powerButton.modelData.label
                        color: Theme.surface
                        font.weight: Font.Bold
                        font.pixelSize: Theme.font.small
                    }
                }

                StateLayer {
                    onClicked: {
                        const action = powerButton.modelData;
                        if (action.confirm && !powerButton.isArmed) {
                            powerRow.armed = action.id;
                            disarm.restart();
                            return;
                        }
                        powerRow.armed = "";
                        AppLauncher.hide();
                        // Con animación previa (ver services/Power.qml)
                        Power.run(action.id);
                    }
                }
            }
        }
    }
}
