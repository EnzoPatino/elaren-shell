pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../theme"
import "../../components"
import "../../services"

// Reproductor expandido: vista "Música" (y "Letra") de la isla de la barra.
//
// - Toma el color de la portada (acento) y la usa difuminada de fondo.
// - Vinilo con inercia y brazo; la rueda sobre el disco adelanta/retrocede 5 s.
// - Barras y halo reaccionan al nivel de audio real de la salida (PipeWire).
// - Progreso arrastrable con burbuja de tiempo; clic en la duración alterna
//   entre total y restante.
InlineCard {
    id: root

    property bool showRemaining: false
    readonly property color accent: Media.accent

    // Modo letra: solo el disco, el visualizador y la letra sincronizada.
    // Se alterna con el botón de arriba a la derecha.
    property bool lyricsMode: false
    property real lyricsAmount: lyricsMode ? 1 : 0
    Behavior on lyricsAmount { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.emphasizedDecel } }

    // cava y la búsqueda de letra solo trabajan con la vista visible. Al
    // cerrar la isla el Loader destruye la vista y los Binding devuelven el
    // valor anterior (falso).
    Binding {
        target: Visualizer
        property: "popupActive"
        value: root.visible
    }

    Binding {
        target: Lyrics
        property: "wanted"
        value: root.visible && root.lyricsMode
    }

    cardWidth: 620
    padding: 22
    borderColor: Qt.alpha(accent, 0.28)

    // Rebote del disco al cambiar de tema
    Connections {
        target: Media
        function onTitleChanged() { vinyl.bump(); }
    }

    // ── Nivel de audio real (pico de la salida por defecto) ───────────────
    property real level: 0
    PwNodePeakMonitor {
        id: peaks
        node: Pipewire.defaultAudioSink
        enabled: root.visible && Media.playing
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Tiempo y nivel suavizado (ataque rápido, caída lenta) para las barras.
    // Solo corre con la tarjeta visible y con algo que animar: en pausa, una
    // vez que las barras bajaron, se detiene y la tarjeta queda estática.
    property real clock: 0
    FrameAnimation {
        running: root.visible && Theme.anim.scale > 0 && (Media.playing || root.level > 0.002)
        onTriggered: {
            root.clock += frameTime;
            const target = Media.playing ? Math.min(1, peaks.peak * 1.4) : 0;
            const next = root.level + (target - root.level) * (target > root.level ? 0.45 : 0.08);
            root.level = next < 0.002 && !Media.playing ? 0 : next;
        }
    }

    // ── Fondo: portada difuminada + barras ambientales ────────────────────
    decoration: [
        Image {
            id: backdrop
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Basta una miniatura: se va a difuminar igual y el desenfoque
            // sobre una textura chica cuesta mucho menos.
            sourceSize: Qt.size(96, 96)
            visible: false
        },
        MultiEffect {
            anchors.fill: parent
            visible: root.visible
            source: backdrop
            blurEnabled: true
            blur: 1
            blurMax: 32
            saturation: 0.15
            opacity: backdrop.status === Image.Ready ? 0.5 : 0

            Behavior on opacity { Anim { duration: Theme.anim.extraSlow } }
        },
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(Theme.surface, 0.55) }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.surface, 0.82) }
                GradientStop { position: 1; color: Qt.alpha(Theme.surface, 0.9) }
            }
        },
        // Visualizador al pie de la tarjeta: espectro real con cava; sin cava,
        // barras moduladas por el nivel de pico de PipeWire.
        Row {
            id: spectrum

            readonly property int count: Visualizer.barCount
            readonly property bool real: Visualizer.available && Visualizer.bars.length === count
            readonly property real maxHeight: 30 + 22 * root.lyricsAmount

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3
            opacity: 0.22 + 0.33 * root.lyricsAmount

            Repeater {
                model: spectrum.count

                Rectangle {
                    required property int index
                    readonly property real shape: 0.35 + 0.65 * Math.sin(Math.PI * (index + 0.5) / spectrum.count)
                    // Con cava solo depende de sus datos; la onda sintética (que
                    // lee el reloj en cada cuadro) se evalúa únicamente sin cava.
                    readonly property real value: spectrum.real ? Visualizer.bars[index]
                        : root.level * (0.5 + 0.5 * Math.sin(root.clock * (2.1 + (index % 7) * 0.37) + index * 0.9)) * shape

                    anchors.bottom: parent.bottom
                    width: (root.cardWidth - 4) / spectrum.count - spectrum.spacing
                    height: 2 + spectrum.maxHeight * Math.min(1, value)
                    radius: width / 2
                    // Color liso: con decenas de barras cambiando de alto en
                    // cada cuadro, el degradado por barra era lo más caro.
                    color: root.accent
                }
            }
        }
    ]

    Row {
        width: parent.width
        spacing: 26

        Vinyl {
            id: vinyl
            width: 230
            height: 200
            anchors.verticalCenter: parent.verticalCenter
            spinning: Media.playing
            active: root.visible
            cover: Media.artUrl
            accent: root.accent
            level: root.level
            progress: Media.progress
            onScratched: direction => Media.seekBy(direction * 5)
            onClicked: Media.togglePlaying()
        }

        // Panel derecho: detalles y controles, o la letra (modo letra).
        Item {
            id: rightPane

            width: parent.width - vinyl.width - parent.spacing
            height: details.implicitHeight + (lyricsHeight - details.implicitHeight) * root.lyricsAmount
            readonly property int lyricsHeight: 300

        // Botón para alternar el modo letra
        Rectangle {
            id: modeButton
            anchors.top: parent.top
            anchors.right: parent.right
            z: 2
            width: 30
            height: 30
            radius: 15
            color: root.lyricsMode ? Qt.alpha(root.accent, 0.22) : Qt.alpha(Theme.text, 0.06)

            Behavior on color { CAnim {} }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.lyricsMode ? "tune" : "lyrics"
                font.pixelSize: 17
                color: root.lyricsMode ? root.accent : Theme.textMuted
            }

            StateLayer {
                radius: 15
                onClicked: root.lyricsMode = !root.lyricsMode
            }
        }

        LyricsView {
            anchors.fill: parent
            opacity: root.lyricsAmount
            visible: opacity > 0.01
        }

        Column {
            id: details

            width: parent.width
            spacing: 0
            opacity: 1 - root.lyricsAmount
            visible: opacity > 0.01

            // Encabezado: estado + reproductor (selector si hay varios)
            Row {
                width: parent.width
                height: 24
                spacing: 8

                Equalizer {
                    anchors.verticalCenter: parent.verticalCenter
                    active: Media.playing
                    color: root.accent
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Media.playing ? "SONANDO EN " : "EN PAUSA · ") + Media.playerName.toUpperCase()
                    color: Media.playing ? root.accent : Theme.textMuted
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - 30 - modeButton.width)
                }
            }

            Item { width: 1; height: 10 }

            StyledText {
                width: parent.width
                text: Media.title
                font.pixelSize: 24
                font.weight: Font.Bold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 1.05
                animate: true
            }

            Item { width: 1; height: 4 }

            StyledText {
                width: parent.width
                text: Media.artist || "Artista desconocido"
                color: Qt.lighter(root.accent, 1.15)
                font.pixelSize: Theme.font.large
                font.weight: Font.Medium
                elide: Text.ElideRight
                animate: true
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: Media.album
                color: Theme.textMuted
                font.pixelSize: Theme.font.small + 1
                elide: Text.ElideRight
                animate: true
            }

            Item { width: 1; height: 16 }

            SeekBar {
                width: parent.width
                accent: root.accent
            }

            Item { width: 1; height: 4 }

            // Tiempos
            Item {
                width: parent.width
                height: 16

                StyledText {
                    text: Media.positionText
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                    font.features: { "tnum": 1 }
                }

                StyledText {
                    anchors.right: parent.right
                    text: root.showRemaining ? Media.remainingText : Media.durationText
                    color: durationTouch.containsMouse ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.font.small
                    font.features: { "tnum": 1 }

                    MouseArea {
                        id: durationTouch
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showRemaining = !root.showRemaining
                    }
                }
            }

            Item { width: 1; height: 10 }

            // Controles
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                TransportButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "shuffle"
                    small: true
                    available: Media.shuffleSupported
                    active: Media.shuffled
                    onClicked: Media.toggleShuffle()
                }
                TransportButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_previous"
                    available: Media.active?.canGoPrevious ?? false
                    onClicked: Media.previous()
                }
                TransportButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Media.playing ? "pause" : "play_arrow"
                    primary: true
                    available: Media.active?.canTogglePlaying ?? false
                    onClicked: Media.togglePlaying()
                }
                TransportButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_next"
                    available: Media.active?.canGoNext ?? false
                    onClicked: Media.next()
                }
                TransportButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Media.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    small: true
                    available: Media.loopSupported
                    active: Media.loopState !== MprisLoopState.None
                    onClicked: Media.cycleLoop()
                }
            }

            Item { width: 1; height: 12 }

            // Pie: volumen del reproductor, selector y "abrir"
            Row {
                width: parent.width
                height: 28
                spacing: 8

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Media.volumeSupported
                    text: Media.volume <= 0 ? "volume_off" : Media.volume < 0.5 ? "volume_down" : "volume_up"
                    color: Theme.textMuted
                    font.pixelSize: 16
                }

                Slim {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Media.volumeSupported
                    width: 90
                    value: Media.volume
                    accent: root.accent
                    onMoved: value => Media.setVolume(value)
                }

                Item {
                    width: Math.max(0, parent.width - (Media.volumeSupported ? 16 + 90 + 16 : 0) - players.width - openButton.width - 8)
                    height: 1
                }

                // Selector de reproductor (solo si hay más de uno)
                Row {
                    id: players
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: Media.players.length > 1

                    Repeater {
                        model: Media.players.length > 1 ? Media.players : []

                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool current: modelData === Media.active

                            width: chipLabel.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: current ? Qt.alpha(root.accent, 0.22) : Qt.alpha(Theme.text, 0.06)
                            border.width: 1
                            border.color: current ? Qt.alpha(root.accent, 0.5) : "transparent"

                            Behavior on color { CAnim {} }

                            StyledText {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: chip.modelData.identity
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: chip.current ? Theme.text : Theme.textMuted
                            }

                            StateLayer {
                                radius: 12
                                onClicked: Media.select(chip.modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    id: openButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Media.active?.canRaise ?? false
                    width: visible ? 28 : 0
                    height: 28
                    radius: 14
                    color: "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "open_in_new"
                        font.pixelSize: 16
                        color: Theme.textMuted
                        animateChange: false
                    }

                    StateLayer {
                        radius: 14
                        onClicked: {
                            Media.raise();
                            root.dismissed();
                        }
                    }
                }
            }
        }
        }
    }

    // ── Piezas internas ───────────────────────────────────────────────────

    // Letra sincronizada: la línea actual se destaca y queda centrada; un clic
    // en una línea salta a ese momento del tema.
    component LyricsView: Item {
        id: view

        // Desvanece los bordes superior e inferior de la lista.
        Item {
            id: fadeMask
            anchors.fill: list
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.18; color: "black" }
                    GradientStop { position: 0.82; color: "black" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }

        ListView {
            id: list

            anchors.fill: parent
            anchors.topMargin: 34
            anchors.bottomMargin: 30
            anchors.rightMargin: 4
            visible: Lyrics.status === "found"
            clip: true
            spacing: 2
            model: Lyrics.lines
            currentIndex: Math.max(0, Lyrics.currentIndex)
            interactive: !Lyrics.synced
            boundsBehavior: Flickable.StopAtBounds

            highlightRangeMode: Lyrics.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
            preferredHighlightBegin: height * 0.36
            preferredHighlightEnd: height * 0.36 + 34
            highlightMoveDuration: 600
            highlightMoveVelocity: -1

            layer.enabled: view.visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: fadeMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            header: Item { width: 1; height: Lyrics.synced ? list.height * 0.3 : 0 }
            footer: Item { width: 1; height: Lyrics.synced ? list.height * 0.5 : 0 }

            delegate: Item {
                id: line

                required property var modelData
                required property int index
                readonly property bool current: Lyrics.synced && index === Lyrics.currentIndex
                readonly property int distance: Math.abs(index - Lyrics.currentIndex)

                width: list.width
                height: lineText.implicitHeight + 10

                StyledText {
                    id: lineText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width / scale
                    transformOrigin: Item.Left
                    text: line.modelData.text || "♪"
                    wrapMode: Text.Wrap
                    font.pixelSize: 20
                    font.weight: line.current ? Font.Bold : Font.DemiBold
                    color: line.current ? root.accent : Theme.text
                    scale: line.current || !Lyrics.synced ? 1 : 0.82
                    opacity: !Lyrics.synced ? 0.85
                        : line.current ? 1
                        : line.index < Lyrics.currentIndex ? 0.3
                        : Math.max(0.25, 0.65 - line.distance * 0.1)

                    Behavior on scale { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressive } }
                    Behavior on opacity { Anim { duration: Theme.anim.normal } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Lyrics.synced && Media.canScrub
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Media.seekTo(line.modelData.time)
                }
            }
        }

        // Estados: buscando / sin letra
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: Lyrics.status !== "found"

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lyrics.status === "loading" ? "lyrics" : "music_off"
                font.pixelSize: 34
                color: root.accent
                animateChange: false

                SequentialAnimation on opacity {
                    running: Lyrics.status === "loading"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lyrics.status === "loading" ? "Buscando la letra…" : "No encontré la letra de este tema"
                color: Theme.textMuted
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Media.title
                color: Theme.text
                font.weight: Font.Bold
                width: Math.min(implicitWidth, view.width)
                elide: Text.ElideRight
            }
        }
    }

    // Tres barritas animadas junto al estado (quietas en pausa).
    component Equalizer: Row {
        id: eq

        property bool active: false
        property color color: Theme.primary

        spacing: 2
        height: 12

        Repeater {
            model: 3

            Rectangle {
                id: eqBar
                required property int index
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                color: eq.color
                height: eq.active
                    ? 3 + 9 * (0.5 + 0.5 * Math.sin(root.clock * (6 + index * 1.7) + index * 2)) * Math.max(0.35, root.level)
                    : 3
            }
        }
    }

    // Barra de progreso: crece al pasar el ratón y muestra el tiempo al arrastrar.
    component SeekBar: Item {
        id: seek

        property color accent: Theme.primary
        readonly property bool engaged: seekTouch.containsMouse || seekTouch.pressed
        readonly property real shown: seekTouch.pressed ? dragValue : Media.progress
        property real dragValue: 0

        height: 18

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: seek.engaged ? 8 : 5
            radius: height / 2
            color: Qt.alpha(Theme.text, 0.12)

            Behavior on height { Anim { duration: Theme.anim.fast } }

            Rectangle {
                width: Math.max(parent.height, parent.width * seek.shown)
                height: parent.height
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.darker(seek.accent, 1.3) }
                    GradientStop { position: 1; color: seek.accent }
                }

                Behavior on width {
                    enabled: !seekTouch.pressed
                    Anim { duration: 450; easing.bezierCurve: Theme.anim.emphasizedDecel }
                }
            }
        }

        Rectangle {
            id: knob
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, parent.width * seek.shown - width / 2))
            width: seek.engaged ? 16 : 0
            height: width
            radius: width / 2
            color: "white"
            visible: Media.canScrub

            Behavior on width { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }
        }

        // Burbuja con el tiempo mientras se arrastra
        Rectangle {
            anchors.bottom: knob.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: knob.horizontalCenter
            width: bubble.implicitWidth + 12
            height: 20
            radius: 10
            color: seek.accent
            opacity: seekTouch.pressed ? 1 : 0
            scale: seekTouch.pressed ? 1 : 0.6

            Behavior on opacity { Anim { duration: Theme.anim.fast } }
            Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }

            StyledText {
                id: bubble
                anchors.centerIn: parent
                text: Media.formatTime(Media.duration * seek.dragValue)
                color: Theme.surface
                font.pixelSize: 10
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: seekTouch
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            enabled: Media.canScrub
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            function valueAt(x: real): real {
                return Math.max(0, Math.min(1, x / width));
            }

            onPressed: event => seek.dragValue = valueAt(event.x)
            onPositionChanged: event => { if (pressed) seek.dragValue = valueAt(event.x); }
            onReleased: Media.seekTo(Media.duration * seek.dragValue)
        }
    }

    // Deslizador fino (volumen del reproductor)
    component Slim: Item {
        id: slim

        property real value: 0
        property color accent: Theme.primary
        signal moved(real value)

        height: 14

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.alpha(Theme.text, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, slim.value))
                height: parent.height
                radius: 2
                color: slim.accent

                Behavior on width { Anim { duration: Theme.anim.fast } }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: event => slim.moved(Math.max(0, Math.min(1, event.x / width)))
            onPositionChanged: event => { if (pressed) slim.moved(Math.max(0, Math.min(1, event.x / width))); }
        }

        WheelHandler {
            onWheel: event => slim.moved(slim.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    component TransportButton: Rectangle {
        id: button

        property string icon
        property bool small: false
        property bool primary: false
        property bool active: false
        property bool available: true
        signal clicked()

        width: primary ? 54 : small ? 34 : 42
        height: width
        radius: width / 2
        color: primary ? root.accent : active ? Qt.alpha(root.accent, 0.2) : "transparent"
        opacity: available ? 1 : 0.35
        scale: touch.pressed && available ? 0.88 : 1

        Behavior on color { CAnim { duration: Theme.anim.slow } }
        Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }

        // Sombra de color bajo el botón principal
        Rectangle {
            visible: button.primary
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 3
            width: parent.width + 8
            height: width
            radius: width / 2
            color: Qt.alpha(root.accent, 0.25 + root.level * 0.25)
            z: -1
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            color: button.primary ? "#14151b" : button.active ? root.accent : Theme.text
            font.pixelSize: button.primary ? 28 : button.small ? 18 : 24
        }

        StateLayer {
            id: touch
            radius: button.width / 2
            disabled: !button.available
            color: button.primary ? "#14151b" : Theme.text
            onClicked: button.clicked()
        }
    }
}
