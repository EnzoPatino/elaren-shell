pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Panel de Configuración de Elaren.
//
// Se abre desde el engranaje del lanzador, con clic derecho en el botón
// "Apps" de la barra, o por IPC (qs ipc -p <ruta>/shell.qml call settings toggle).
// Todo cambio se aplica al instante y se guarda en ~/.config/elaren/settings.json.
PanelWindow {
    id: root

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
    WlrLayershell.namespace: "elaren-settings"
    WlrLayershell.keyboardFocus: Settings.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    readonly property list<var> pages: [
        { id: "visualizer", name: "Visualizador", icon: "graphic_eq", description: "Barras y ondas sobre el fondo mientras suena música" },
        { id: "widgets", name: "Widgets", icon: "widgets", description: "Reloj, saludo, música, sistema y clima en el escritorio" },
        { id: "appearance", name: "Apariencia", icon: "palette", description: "Color de acento y animaciones" },
        { id: "bar", name: "Barra superior", icon: "toolbar", description: "Qué módulos se muestran" },
        { id: "dock", name: "Dock", icon: "space_dashboard", description: "Comportamiento y tamaño de los iconos" },
        { id: "wallpaper", name: "Fondo", icon: "wallpaper", description: "Quién dibuja el fondo y su movimiento" },
        { id: "about", name: "Acerca de", icon: "info", description: "Archivo de configuración y restablecer" }
    ]
    readonly property var currentPage: pages.find(p => p.id === Settings.page) ?? pages[0]
    property int slideDirection: 1

    function goTo(id: string): void {
        const from = pages.findIndex(p => p.id === Settings.page);
        const to = pages.findIndex(p => p.id === id);
        if (from === to) return;
        slideDirection = to > from ? 1 : -1;
        Settings.page = id;
        pageSlide.restart();
    }

    Connections {
        target: Settings
        function onOpenChanged() {
            progressAnim.easing.bezierCurve = Settings.open ? Theme.anim.expressive : Theme.anim.emphasizedAccel;
            progressAnim.duration = Settings.open ? Theme.anim.slow : Theme.anim.normal;
            root.progress = Settings.open ? 1 : 0;
            if (Settings.open) {
                AppLauncher.hide();
                keyCatcher.forceActiveFocus();
            }
        }
    }

    Behavior on progress { Anim { id: progressAnim } }

    // ── Datos de demostración para las vistas previas ─────────────────────
    // Con música sonando se usa el espectro real; si no, una animación.
    readonly property bool liveAudio: Media.playing && Visualizer.display.length > 0
    property list<real> demo: []
    property list<real> demoCaps: []
    property real demoClock: 0

    FrameAnimation {
        running: root.previewing && !root.liveAudio
        onTriggered: {
            root.demoClock += frameTime;
            const n = Visualizer.barCount;
            const t = root.demoClock;
            const beat = 0.65 + 0.35 * Math.pow(Math.abs(Math.sin(t * 2.4)), 3);
            const out = [];
            const caps = [];
            for (let i = 0; i < n; i++) {
                const x = i / (n - 1);
                const shape = 0.25 + 0.75 * Math.pow(Math.sin(Math.PI * (0.12 + 0.88 * x)), 1.4);
                const wave = 0.5 + 0.5 * (0.5 * Math.sin(t * 2.1 + i * 0.35) + 0.3 * Math.sin(t * 3.7 - i * 0.62) + 0.2 * Math.sin(t * 6.3 + i * 1.1));
                const v = Math.min(1, shape * wave * beat * Config.visualizerGain);
                out.push(v);
                const cap = root.demoCaps[i] ?? 0;
                caps.push(v >= cap ? v : Math.max(v, cap - frameTime * 0.35));
            }
            root.demo = out;
            root.demoCaps = caps;
        }
    }

    // Con el panel cerrado las vistas previas no reciben datos: si no, las
    // seis (la grande y las cinco tarjetas de estilo) se recalculaban en cada
    // cuadro del espectro aunque nadie las viera (~16 ms por cuadro).
    readonly property bool previewing: visible && Settings.page === "visualizer"
    readonly property list<real> previewValues: !previewing ? [] : liveAudio ? Visualizer.display : demo
    readonly property list<real> previewCaps: !previewing ? [] : liveAudio ? Visualizer.caps : demoCaps
    readonly property color previewColor: Config.visualizerColor === "cover" && Media.available ? Media.accent : Theme.primary

    // Fondo oscurecido; clic fuera cierra.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * Math.min(1, root.progress)

        MouseArea {
            anchors.fill: parent
            onClicked: Settings.hide()
        }
    }

    // Esc cierra
    Item {
        id: keyCatcher
        focus: true
        Keys.onEscapePressed: Settings.hide()
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1000, parent.width - 80)
        height: Math.min(680, parent.height - 100)
        radius: 28
        color: Qt.alpha(Theme.surface, 0.95)
        border.color: Qt.alpha("white", 0.08)
        border.width: 1
        clip: true

        opacity: Math.min(1, root.progress)
        scale: 0.92 + 0.08 * root.progress
        transform: Translate { y: 30 * (1 - root.progress) }

        MouseArea { anchors.fill: parent }

        // Resplandor de acento en la esquina
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.08) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }

        // ── Barra lateral ─────────────────────────────────────────────────
        Item {
            id: sidebar

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 18
            width: 220

            Row {
                id: brand
                spacing: 12
                leftPadding: 6

                Rectangle {
                    width: 40
                    height: 40
                    radius: 13
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.primary }
                        GradientStop { position: 1; color: Theme.secondary }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "settings"
                        font.pixelSize: 22
                        color: Theme.textOnPrimary
                        animateChange: false
                        rotation: root.progress * 90
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText {
                        text: "Configuración"
                        font.pixelSize: Theme.font.large + 1
                        font.weight: Font.Bold
                    }
                    StyledText {
                        text: "Elaren"
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                    }
                }
            }

            ListView {
                id: nav

                anchors.top: brand.bottom
                anchors.topMargin: 24
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 2
                interactive: false
                model: root.pages
                currentIndex: root.pages.findIndex(p => p.id === Settings.page)

                highlightFollowsCurrentItem: false
                highlight: Rectangle {
                    width: nav.width
                    height: 42
                    radius: Theme.radius.normal + 2
                    color: Qt.alpha(Theme.primary, 0.16)
                    y: nav.currentItem?.y ?? 0

                    Behavior on y { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }

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
                    id: navItem

                    required property var modelData
                    readonly property bool active: ListView.isCurrentItem

                    width: nav.width
                    height: 42

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        spacing: 12

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: navItem.modelData.icon
                            color: navItem.active ? Theme.primary : Theme.textMuted
                            animateChange: false
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: navItem.modelData.name
                            color: navItem.active ? Theme.text : Theme.textMuted
                            font.weight: navItem.active ? Font.DemiBold : Font.Normal
                        }
                    }

                    StateLayer {
                        radius: Theme.radius.normal + 2
                        onClicked: root.goTo(navItem.modelData.id)
                    }
                }
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
            id: content

            anchors.left: divider.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 22

            // Encabezado de la página
            Item {
                id: header
                width: parent.width
                height: 54

                Column {
                    spacing: 2
                    StyledText {
                        text: root.currentPage.name
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        animate: true
                    }
                    StyledText {
                        text: root.currentPage.description
                        color: Theme.textMuted
                        animate: true
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 36
                    height: 36
                    radius: 18
                    color: Qt.alpha(Theme.text, 0.06)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        animateChange: false
                    }

                    StateLayer {
                        radius: 18
                        onClicked: Settings.hide()
                    }
                }
            }

            Flickable {
                id: scroller

                anchors.top: header.bottom
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentHeight: pageLoader.height + 16
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: pageLoader
                    width: scroller.width - 8
                    sourceComponent: {
                        switch (Settings.page) {
                        case "widgets": return widgetsPage;
                        case "appearance": return appearancePage;
                        case "bar": return barPage;
                        case "dock": return dockPage;
                        case "wallpaper": return wallpaperPage;
                        case "about": return aboutPage;
                        default: return visualizerPage;
                        }
                    }
                    onLoaded: scroller.contentY = 0
                }
            }

            ParallelAnimation {
                id: pageSlide
                Anim { target: pageLoader; property: "x"; from: 40 * root.slideDirection; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
                Anim { target: pageLoader; property: "opacity"; from: 0; to: 1 }
            }
        }
    }

    // ══ Páginas ═══════════════════════════════════════════════════════════

    // ── Visualizador ──────────────────────────────────────────────────────
    Component {
        id: visualizerPage

        Column {
            spacing: 20

            // Vista previa grande, con la configuración actual
            Rectangle {
                width: parent.width
                height: 170
                radius: Theme.radius.large
                color: Qt.alpha("black", 0.25)
                border.width: 1
                border.color: Qt.alpha(root.previewColor, 0.25)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1; color: Qt.alpha(root.previewColor, 0.18) }
                    }
                }

                SpectrumView {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.bottomMargin: 8
                    values: root.previewValues
                    caps: root.previewCaps
                    style: Config.visualizerStyle
                    colorMode: Config.visualizerColor
                    color: root.previewColor
                    maxHeight: height * Math.min(1, Config.visualizerHeight / 260)
                    barWidth: Config.visualizerBarWidth
                    showCaps: Config.visualizerCaps
                    opacity: Config.visualizerOpacity
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 12
                    width: liveLabel.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: Qt.alpha("black", 0.35)

                    Row {
                        id: liveLabel
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 3.5
                            color: root.liveAudio ? Theme.error : Theme.textMuted

                            SequentialAnimation on opacity {
                                running: root.liveAudio && root.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1; duration: 600 }
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.liveAudio ? "EN VIVO · " + Media.title : "VISTA PREVIA"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            width: Math.min(implicitWidth, 360)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Selector de estilo con mini-vistas animadas
            SettingsCard {
                title: "Estilo"
                icon: "auto_awesome"

                Grid {
                    id: styleGrid
                    width: parent.width
                    columns: 5
                    spacing: 8
                    padding: 8

                    readonly property real cardWidth: (width - padding * 2 - spacing * (columns - 1)) / columns

                    Repeater {
                        model: [
                            { id: "bars", name: "Barras", hint: "Estilo cava" },
                            { id: "blocks", name: "Bloques", hint: "Vúmetro LED" },
                            { id: "wave", name: "Onda", hint: "Rellena" },
                            { id: "mirror", name: "Espejo", hint: "Onda doble" },
                            { id: "line", name: "Línea", hint: "Minimalista" }
                        ]

                        Rectangle {
                            id: styleCard

                            required property var modelData
                            readonly property bool selected: Config.visualizerStyle === modelData.id

                            width: styleGrid.cardWidth
                            height: 118
                            radius: 14
                            color: selected ? Qt.alpha(Theme.primary, 0.14) : Qt.alpha("black", 0.2)
                            border.width: selected ? 2 : 1
                            border.color: selected ? Theme.primary : Qt.alpha("white", 0.06)
                            scale: cardTouch.pressed ? 0.95 : cardTouch.containsMouse ? 1.03 : 1

                            Behavior on color { CAnim {} }
                            Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }

                            SpectrumView {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                height: 62
                                values: root.previewValues.filter((_, i) => i % 2 === 0)
                                caps: root.previewCaps.filter((_, i) => i % 2 === 0)
                                style: styleCard.modelData.id
                                colorMode: Config.visualizerColor
                                color: root.previewColor
                                barWidth: Config.visualizerBarWidth
                                showCaps: Config.visualizerCaps
                                lineWidth: 2
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                spacing: 0

                                StyledText {
                                    text: styleCard.modelData.name
                                    font.weight: Font.Bold
                                    color: styleCard.selected ? Theme.primary : Theme.text
                                }
                                StyledText {
                                    text: styleCard.modelData.hint
                                    color: Theme.textMuted
                                    font.pixelSize: 10
                                }
                            }

                            // Tilde de seleccionado
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                width: 20
                                height: 20
                                radius: 10
                                color: Theme.primary
                                scale: styleCard.selected ? 1 : 0

                                Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "check"
                                    font.pixelSize: 14
                                    color: Theme.textOnPrimary
                                    animateChange: false
                                }
                            }

                            MouseArea {
                                id: cardTouch
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.visualizerStyle = styleCard.modelData.id
                            }
                        }
                    }
                }
            }

            SettingsCard {
                title: "Color y forma"
                icon: "brush"

                SwitchRow {
                    icon: "visibility"
                    title: "Mostrar visualizador"
                    description: "Aparece sobre el fondo mientras suena música"
                    checked: Config.visualizerEnabled
                    onToggled: value => Config.visualizerEnabled = value
                }
                ChoiceRow {
                    icon: "colorize"
                    title: "Color"
                    description: "De dónde sale el color de las barras"
                    current: Config.visualizerColor
                    options: [
                        { value: "cover", label: "Portada", icon: "album" },
                        { value: "accent", label: "Tema", icon: "palette" },
                        { value: "rainbow", label: "Arcoíris", icon: "gradient" }
                    ]
                    onChosen: value => Config.visualizerColor = value
                }
                SwitchRow {
                    icon: "vertical_align_top"
                    title: "Tapitas"
                    description: "Marcas que caen despacio sobre cada barra"
                    checked: Config.visualizerCaps
                    onToggled: value => Config.visualizerCaps = value
                }
                SliderRow {
                    icon: "view_week"
                    title: "Cantidad de barras"
                    value: Config.visualizerBars
                    from: 16
                    to: 96
                    stepSize: 8
                    display: v => Math.round(v)
                    onMoved: value => Config.visualizerBars = Math.round(value)
                }
                SliderRow {
                    icon: "width"
                    title: "Grosor de las barras"
                    value: Config.visualizerBarWidth
                    from: 0.2
                    to: 0.95
                    stepSize: 0.05
                    display: v => Math.round(v * 100) + "%"
                    onMoved: value => Config.visualizerBarWidth = value
                }
            }

            SettingsCard {
                title: "Tamaño y respuesta"
                icon: "tune"

                SliderRow {
                    icon: "height"
                    title: "Altura"
                    description: "Hasta dónde llegan las barras más altas"
                    value: Config.visualizerHeight
                    from: 80
                    to: 480
                    stepSize: 10
                    display: v => Math.round(v) + " px"
                    onMoved: value => Config.visualizerHeight = Math.round(value)
                }
                SliderRow {
                    icon: "opacity"
                    title: "Opacidad"
                    value: Config.visualizerOpacity
                    from: 0.2
                    to: 1
                    stepSize: 0.05
                    display: v => Math.round(v * 100) + "%"
                    onMoved: value => Config.visualizerOpacity = value
                }
                SliderRow {
                    icon: "speed"
                    title: "Sensibilidad"
                    description: "Cuánto saltan las barras con el volumen"
                    value: Config.visualizerGain
                    from: 0.5
                    to: 2.5
                    stepSize: 0.1
                    display: v => "×" + v.toFixed(1)
                    onMoved: value => Config.visualizerGain = value
                }
            }

            SettingsCard {
                title: "Ubicación"
                icon: "open_with"

                RowBase {
                    icon: "drag_pan"
                    title: "Acomodar con el ratón"
                    description: "Arrastralo a cualquier lugar; rueda: largo, clic derecho: girar"

                    ActionButton {
                        label: "Mover"
                        onClicked: {
                            Config.visualizerEnabled = true;
                            Settings.hide();
                            Visualizer.placing = true;
                        }
                    }
                }
                ChoiceRow {
                    icon: "place_item"
                    title: "Lugar"
                    description: "Atajos: cada uno ya mira hacia el centro"
                    current: {
                        const x = Config.visualizerX, y = Config.visualizerY, d = Config.visualizerDirection;
                        const near = (a, b) => Math.abs(a - b) < 0.02;
                        if (near(x, 0.5) && near(y, 1) && d === "up") return "bottom";
                        if (near(x, 0.5) && near(y, 0) && d === "down") return "top";
                        if (near(x, 0) && near(y, 0.5) && d === "right") return "left";
                        if (near(x, 1) && near(y, 0.5) && d === "left") return "right";
                        if (near(x, 0.5) && near(y, 0.5)) return "center";
                        return "";
                    }
                    options: [
                        { value: "bottom", label: "Abajo" },
                        { value: "top", label: "Arriba" },
                        { value: "left", label: "Izq." },
                        { value: "right", label: "Der." },
                        { value: "center", label: "Centro" }
                    ]
                    onChosen: value => {
                        const presets = {
                            bottom: { x: 0.5, y: 1, d: "up" },
                            top: { x: 0.5, y: 0, d: "down" },
                            left: { x: 0, y: 0.5, d: "right" },
                            right: { x: 1, y: 0.5, d: "left" },
                            center: { x: 0.5, y: 0.5, d: Config.visualizerDirection }
                        };
                        const p = presets[value];
                        Config.visualizerX = p.x;
                        Config.visualizerY = p.y;
                        Config.visualizerDirection = p.d;
                    }
                }
                ChoiceRow {
                    icon: "explore"
                    title: "Dirección"
                    description: "Hacia dónde crecen las barras"
                    current: Config.visualizerDirection
                    options: [
                        { value: "up", label: "", icon: "arrow_upward" },
                        { value: "down", label: "", icon: "arrow_downward" },
                        { value: "left", label: "", icon: "arrow_back" },
                        { value: "right", label: "", icon: "arrow_forward" }
                    ]
                    onChosen: value => Config.visualizerDirection = value
                }
                SliderRow {
                    icon: "straighten"
                    title: "Largo"
                    description: "Qué parte del borde de la pantalla ocupa"
                    value: Config.visualizerLength
                    from: 0.15
                    to: 1
                    stepSize: 0.01
                    display: v => Math.round(v * 100) + "%"
                    onMoved: value => Config.visualizerLength = value
                }
            }

            ResetButton { section: "visualizer" }

            StyledText {
                width: parent.width
                visible: !Visualizer.available
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.pixelSize: Theme.font.small
                text: "Consejo: instalá cava (sudo apt install cava) para ver el espectro real de la música. Sin cava, las barras siguen el volumen real pero el reparto entre graves y agudos es aproximado."
            }
        }
    }

    // ── Widgets de escritorio ─────────────────────────────────────────────
    Component {
        id: widgetsPage

        Column {
            spacing: 20

            SettingsCard {
                title: "Widgets"
                icon: "widgets"

                SwitchRow {
                    icon: "schedule"
                    title: "Reloj"
                    description: "Hora grande sobre el escritorio"
                    checked: Config.widgetClockEnabled
                    onToggled: value => Config.widgetClockEnabled = value
                }
                ChoiceRow {
                    visible: Config.widgetClockEnabled
                    icon: "style"
                    title: "Estilo del reloj"
                    current: Config.widgetClockStyle
                    options: [
                        { value: "digital", label: "Digital", icon: "pin" },
                        { value: "analog", label: "Analógico", icon: "nest_clock_farsight_analog" },
                        { value: "words", label: "En palabras", icon: "text_fields" }
                    ]
                    onChosen: value => Config.widgetClockStyle = value
                }
                SwitchRow {
                    visible: Config.widgetClockEnabled && Config.widgetClockStyle === "digital"
                    icon: "timer"
                    title: "Mostrar segundos"
                    checked: Config.widgetClockSeconds
                    onToggled: value => Config.widgetClockSeconds = value
                }
                SwitchRow {
                    icon: "waving_hand"
                    title: "Saludo"
                    description: "Buenos días / tardes / noches, con clima y música"
                    checked: Config.widgetGreetingEnabled
                    onToggled: value => Config.widgetGreetingEnabled = value
                }
                SwitchRow {
                    icon: "album"
                    title: "Música"
                    description: "Portada, progreso y controles (solo con un reproductor abierto)"
                    checked: Config.widgetMediaEnabled
                    onToggled: value => Config.widgetMediaEnabled = value
                }
                SwitchRow {
                    icon: "monitor_heart"
                    title: "Monitor del sistema"
                    description: "CPU, memoria, temperatura y red"
                    checked: Config.widgetSystemEnabled
                    onToggled: value => Config.widgetSystemEnabled = value
                }
                SwitchRow {
                    icon: "partly_cloudy_day"
                    title: "Clima"
                    description: "Actual y próximos 3 días (Open-Meteo)"
                    checked: Config.widgetWeatherEnabled
                    onToggled: value => Config.widgetWeatherEnabled = value
                }
                TextFieldRow {
                    visible: Config.widgetWeatherEnabled
                    icon: "location_on"
                    title: "Ciudad"
                    description: "Solo se envía el nombre de la ciudad a Open-Meteo"
                    text: Config.weatherCity
                    placeholder: "Ej.: Buenos Aires"
                    onCommitted: value => Config.weatherCity = value.trim()
                }
            }

            SettingsCard {
                title: "Aspecto y posición"
                icon: "tune"

                SwitchRow {
                    icon: "crop_square"
                    title: "Tarjetas de vidrio"
                    description: "Si se apaga, solo texto con sombra"
                    checked: Config.widgetCards
                    onToggled: value => Config.widgetCards = value
                }
                SliderRow {
                    icon: "aspect_ratio"
                    title: "Tamaño"
                    value: Config.widgetScale
                    from: 0.6
                    to: 1.6
                    stepSize: 0.05
                    display: v => Math.round(v * 100) + "%"
                    onMoved: value => Config.widgetScale = value
                }
                SwitchRow {
                    icon: "lock"
                    title: "Bloquear posición"
                    description: "Si está desbloqueado, se arrastran con el ratón"
                    checked: Config.widgetsLocked
                    onToggled: value => Config.widgetsLocked = value
                }
            }

            ResetButton { section: "widget|weatherCity" }
        }
    }

    // ── Apariencia ────────────────────────────────────────────────────────
    Component {
        id: appearancePage

        Column {
            spacing: 20

            SettingsCard {
                title: "Color de acento"
                icon: "palette"

                Flow {
                    width: parent.width
                    spacing: 10
                    padding: 12

                    Repeater {
                        model: Theme.accentPresets

                        Column {
                            id: swatch
                            required property var modelData
                            readonly property bool selected: Config.accent === modelData.id
                            spacing: 6

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 52
                                height: 52
                                radius: 26
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: swatch.modelData.primary }
                                    GradientStop { position: 1; color: swatch.modelData.secondary }
                                }
                                border.width: swatch.selected ? 3 : 0
                                border.color: Theme.text
                                scale: swatchTouch.pressed ? 0.9 : swatchTouch.containsMouse ? 1.08 : 1

                                Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "check"
                                    color: swatch.modelData.on
                                    scale: swatch.selected ? 1 : 0
                                    animateChange: false

                                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                                }

                                MouseArea {
                                    id: swatchTouch
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.accent = swatch.modelData.id
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: swatch.modelData.name
                                font.pixelSize: Theme.font.small
                                color: swatch.selected ? Theme.text : Theme.textMuted
                            }
                        }
                    }
                }
            }

            SettingsCard {
                title: "Movimiento"
                icon: "animation"

                SliderRow {
                    icon: "slow_motion_video"
                    title: "Velocidad de las animaciones"
                    description: "0 las desactiva; más de 1 las hace más lentas"
                    value: Config.animationScale
                    from: 0
                    to: 2
                    stepSize: 0.1
                    display: v => v === 0 ? "No" : "×" + v.toFixed(1)
                    onMoved: value => Config.animationScale = value
                }
            }

            ResetButton { section: "accent|animationScale" }
        }
    }

    // ── Barra superior ────────────────────────────────────────────────────
    Component {
        id: barPage

        Column {
            spacing: 20

            SettingsCard {
                title: "Módulos"
                icon: "view_module"

                SwitchRow {
                    icon: "workspaces"
                    title: "Escritorios"
                    checked: Config.barShowWorkspaces
                    onToggled: value => Config.barShowWorkspaces = value
                }
                ChoiceRow {
                    icon: "format_list_numbered"
                    title: "Rótulos de escritorios"
                    description: "Cómo se ve cada escritorio en la barra"
                    current: Config.barWorkspaceStyle
                    options: [
                        { value: "numbers", label: "1 2 3" },
                        { value: "roman", label: "I II III" },
                        { value: "kanji", label: "一 二 三" },
                        { value: "dots", label: "• • •" },
                        { value: "pacman", label: "Pac-Man" }
                    ]
                    onChosen: value => Config.barWorkspaceStyle = value
                }
                SwitchRow {
                    icon: "web_asset"
                    title: "Ventana activa"
                    description: "Icono y título de la ventana enfocada"
                    checked: Config.barShowActiveWindow
                    onToggled: value => Config.barShowActiveWindow = value
                }
                SwitchRow {
                    icon: "memory"
                    title: "Sistema"
                    description: "CPU, memoria y temperatura"
                    checked: Config.barShowSystem
                    onToggled: value => Config.barShowSystem = value
                }
                SwitchRow {
                    icon: "music_note"
                    title: "Música"
                    checked: Config.barShowMedia
                    onToggled: value => Config.barShowMedia = value
                }
                SwitchRow {
                    icon: "apps"
                    title: "Bandeja del sistema"
                    checked: Config.barShowTray
                    onToggled: value => Config.barShowTray = value
                }
            }

            SettingsCard {
                title: "Estado (derecha)"
                icon: "tune"

                SwitchRow {
                    icon: "coffee"
                    title: "Cafeína"
                    description: "Evitar que la pantalla se apague"
                    checked: Config.barShowCaffeine
                    onToggled: value => Config.barShowCaffeine = value
                }
                SwitchRow {
                    icon: "wifi"
                    title: "Red"
                    checked: Config.barShowNetwork
                    onToggled: value => Config.barShowNetwork = value
                }
                SwitchRow {
                    icon: "brightness_6"
                    title: "Brillo"
                    checked: Config.barShowBrightness
                    onToggled: value => Config.barShowBrightness = value
                }
                SwitchRow {
                    icon: "volume_up"
                    title: "Volumen"
                    checked: Config.barShowVolume
                    onToggled: value => Config.barShowVolume = value
                }
                SwitchRow {
                    icon: "battery_full"
                    title: "Batería"
                    checked: Config.barShowBattery
                    onToggled: value => Config.barShowBattery = value
                }
            }

            ResetButton { section: "bar" }
        }
    }

    // ── Dock ──────────────────────────────────────────────────────────────
    Component {
        id: dockPage

        Column {
            spacing: 20

            SettingsCard {
                title: "Comportamiento"
                icon: "space_dashboard"

                SwitchRow {
                    icon: "visibility"
                    title: "Mostrar dock"
                    checked: Config.dockEnabled
                    onToggled: value => Config.dockEnabled = value
                }
                SwitchRow {
                    icon: "unfold_less"
                    title: "Ocultar automáticamente"
                    description: "Aparece al llevar el ratón al borde inferior"
                    checked: Config.dockAutoHide
                    onToggled: value => Config.dockAutoHide = value
                }
                SwitchRow {
                    icon: "zoom_in"
                    title: "Ampliar al pasar el ratón"
                    checked: Config.dockMagnification
                    onToggled: value => Config.dockMagnification = value
                }
                SliderRow {
                    icon: "photo_size_select_large"
                    title: "Tamaño de los iconos"
                    value: Config.dockIconSize
                    from: 32
                    to: 72
                    stepSize: 2
                    display: v => Math.round(v) + " px"
                    onMoved: value => Config.dockIconSize = Math.round(value)
                }
            }

            ResetButton { section: "dock" }
        }
    }

    // ── Fondo ─────────────────────────────────────────────────────────────
    Component {
        id: wallpaperPage

        Column {
            spacing: 20

            SettingsCard {
                title: "Fondo de pantalla"
                icon: "wallpaper"

                ChoiceRow {
                    icon: "brush"
                    title: "Quién dibuja el fondo"
                    description: "Auto usa skwd-wall si su daemon está en modo standalone"
                    current: Config.wallpaperProviderSetting
                    options: [
                        { value: "auto", label: "Auto" },
                        { value: "elaren", label: "Elaren" },
                        { value: "skwd", label: "skwd-wall" }
                    ]
                    onChosen: value => Config.wallpaperProviderSetting = value
                }
                SliderRow {
                    icon: "swap_horiz"
                    title: "Paralaje"
                    description: "Cuánto se desliza el fondo al cambiar de escritorio"
                    value: Config.wallpaperParallax
                    from: 0
                    to: 80
                    stepSize: 4
                    display: v => Math.round(v) + " px"
                    onMoved: value => Config.wallpaperParallax = Math.round(value)
                }
            }

            ResetButton { section: "wallpaper" }
        }
    }

    // ── Acerca de ─────────────────────────────────────────────────────────
    Component {
        id: aboutPage

        Column {
            spacing: 20

            SettingsCard {
                title: "Archivo de configuración"
                icon: "description"

                RowBase {
                    icon: "folder_open"
                    title: "settings.json"
                    description: Config.file

                    ActionButton {
                        label: "Abrir"
                        onClicked: Quickshell.execDetached(["xdg-open", Config.file])
                    }
                }
            }

            SettingsCard {
                title: "Restablecer"
                icon: "restart_alt"

                RowBase {
                    icon: "warning"
                    title: "Volver todo a los valores por defecto"
                    description: "Afecta a todas las secciones. Pide confirmación."

                    ActionButton {
                        id: resetAll
                        property bool armed: false
                        label: armed ? "¿Seguro?" : "Restablecer"
                        danger: armed
                        onClicked: {
                            if (!armed) {
                                armed = true;
                                disarm.restart();
                                return;
                            }
                            armed = false;
                            Config.reset("");
                        }

                        Timer {
                            id: disarm
                            interval: 3000
                            onTriggered: resetAll.armed = false
                        }
                    }
                }
            }
        }
    }

    // ── Piezas internas ───────────────────────────────────────────────────
    component ActionButton: Rectangle {
        id: action

        property string label
        property bool danger: false
        signal clicked()

        width: actionLabel.implicitWidth + 28
        height: 32
        radius: 16
        color: danger ? Theme.error : Qt.alpha(Theme.primary, 0.18)

        Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressive } }
        Behavior on color { CAnim {} }

        StyledText {
            id: actionLabel
            anchors.centerIn: parent
            text: action.label
            font.weight: Font.Bold
            color: action.danger ? Theme.surface : Theme.primary
        }

        StateLayer {
            radius: 16
            onClicked: action.clicked()
        }
    }

    // Restablece las claves de una sección (prefijos separados por "|").
    component ResetButton: Item {
        id: reset

        property string section

        width: parent?.width ?? 0
        height: 36

        ActionButton {
            anchors.right: parent.right
            label: "Restablecer esta sección"
            onClicked: {
                for (const prefix of reset.section.split("|")) Config.reset(prefix);
            }
        }
    }
}
