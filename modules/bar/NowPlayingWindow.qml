pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Reproductor expandido: vinilo giratorio, portada, progreso y controles.
PanelWindow {
    id: root

    property bool open: false
    property real progress: 0

    signal dismissed()

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
    WlrLayershell.namespace: "elaren-now-playing"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        item: backdrop
        radius: 0
    }

    onOpenChanged: {
        progressAnim.easing.bezierCurve = open ? Theme.anim.emphasizedDecel : Theme.anim.emphasizedAccel;
        progressAnim.duration = open ? Theme.anim.slow : Theme.anim.normal;
        progress = open ? 1 : 0;
    }

    Behavior on progress { Anim { id: progressAnim } }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.dismissed()
    }

    // Portada difuminada detrás de la tarjeta para que el reproductor tome
    // los colores del disco sin competir con el texto.
    Image {
        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(960, 540)
        opacity: 0.16 * root.progress
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.alpha("#090b13", 0.84 * root.progress)

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(1040, parent.width - 56)
        height: Math.min(640, parent.height - 56)
        radius: 32
        color: Qt.alpha(Theme.surface, 0.92)
        border.color: Theme.glassBorder
        border.width: 1
        opacity: root.progress
        scale: 0.94 + 0.06 * root.progress
        transform: Translate { y: 24 * (1 - root.progress) }

        Behavior on opacity { Anim { duration: Theme.anim.normal } }

        // Capa vacía para que los clics en la tarjeta no cierren el fondo.
        MouseArea { anchors.fill: parent }

        Column {
            id: layout
            anchors.fill: parent
            anchors.margins: 34
            spacing: 24

            Row {
                id: header
                width: parent.width
                height: 38
                spacing: 10

                MaterialIcon {
                    id: headingIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "graphic_eq"
                    color: Media.playing ? Theme.primary : Theme.textMuted
                    font.pixelSize: 20
                    animateChange: false
                }

                StyledText {
                    id: headingText
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.playing ? "SONANDO AHORA" : "REPRODUCTOR"
                    color: Media.playing ? Theme.primary : Theme.textMuted
                    font.pixelSize: Theme.font.small
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                }

                StyledText {
                    id: playerLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.playerName
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                    opacity: Media.playerName ? 1 : 0
                }

                Item {
                    width: Math.max(0, parent.width - headingIcon.implicitWidth - headingText.implicitWidth
                        - playerLabel.implicitWidth - closeButton.width - parent.spacing * 4)
                    height: 1
                }

                Rectangle {
                    id: closeButton
                    width: 38
                    height: 38
                    radius: Theme.radius.full
                    color: "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        color: Theme.textMuted
                        animateChange: false
                    }

                    StateLayer {
                        radius: Theme.radius.full
                        onClicked: root.dismissed()
                    }
                }
            }

            Row {
                id: mainContent
                width: parent.width
                height: parent.height - header.height - layout.spacing
                spacing: 48

                Item {
                    id: vinylStage
                    width: Math.min(420, parent.height, parent.width * 0.47)
                    height: parent.height

                    Rectangle {
                        id: glow
                        anchors.centerIn: record
                        width: record.width + 60
                        height: width
                        radius: width / 2
                        color: Qt.alpha(Theme.primary, Media.playing ? 0.09 : 0.035)
                        scale: Media.playing ? 1.04 : 0.96

                        Behavior on color { CAnim { duration: Theme.anim.slow } }
                        Behavior on scale { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                    }

                    Rectangle {
                        id: record
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(350, parent.width - 24, parent.height - 54)
                        height: width
                        radius: width / 2
                        color: "#171923"
                        border.width: 1
                        border.color: Qt.alpha("white", 0.1)
                        scale: Media.playing ? 1 : 0.985

                        Behavior on scale { Anim { duration: Theme.anim.slow } }

                        NumberAnimation on rotation {
                            running: Media.playing && Theme.anim.scale > 0
                            from: 0
                            to: 360
                            duration: 14000 * Theme.anim.scale
                            loops: Animation.Infinite
                        }

                        Repeater {
                            model: 9

                            Rectangle {
                                required property int index
                                anchors.centerIn: parent
                                width: Math.max(40, record.width - 24 - index * Math.min(25, (record.width - 64) / 8))
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.alpha("white", 0.045 + index * 0.002)
                            }
                        }

                        Rectangle {
                            id: labelRing
                            anchors.centerIn: parent
                            width: Math.min(154, record.width * 0.48)
                            height: width
                            radius: width / 2
                            color: Theme.surfaceHigh
                            border.width: 5
                            border.color: "#20222b"

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                radius: width / 2
                                color: Theme.surfaceContainer

                                Image {
                                    id: cover
                                    anchors.fill: parent
                                    source: Media.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(320, 320)
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { Anim {} }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: cover.status !== Image.Ready
                                    text: "album"
                                    color: Theme.primary
                                    font.pixelSize: 42
                                    animateChange: false
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 7
                                height: width
                                radius: width / 2
                                color: Qt.alpha("white", 0.8)
                            }
                        }
                    }

                    // Acento visual sincronizado con play/pausa; es decorativo,
                    // no se presenta como una lectura real del espectro.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 5
                        height: 32

                        Repeater {
                            model: 13

                            Rectangle {
                                id: bar
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 4
                                height: parent.height
                                radius: 2
                                transformOrigin: Item.Bottom
                                color: index % 2 === 0 ? Theme.primary : Theme.secondary
                                opacity: Media.playing ? 0.82 : 0.32

                                SequentialAnimation on scale {
                                    running: Media.playing && Theme.anim.scale > 0
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: bar.index * 45 }
                                    NumberAnimation { to: 0.18 + (bar.index % 4) * 0.12; duration: 220 + bar.index * 12; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.9; duration: 280 + (12 - bar.index) * 10; easing.type: Easing.InOutSine }
                                }

                                Behavior on opacity { Anim {} }
                            }
                        }
                    }
                }

                Column {
                    id: details
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - vinylStage.width - mainContent.spacing
                    spacing: 0

                    StyledText {
                        text: Media.playing ? "EN REPRODUCCIÓN" : "EN PAUSA"
                        color: Media.playing ? Theme.primary : Theme.textMuted
                        font.pixelSize: Theme.font.small
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                    }

                    StyledText {
                        width: parent.width
                        text: Media.title
                        font.pixelSize: 38
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        lineHeight: 1.08
                        animate: true
                    }

                    StyledText {
                        width: parent.width
                        text: Media.artist || "Artista desconocido"
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.large + 2
                        elide: Text.ElideRight
                        animate: true
                    }

                    StyledText {
                        width: parent.width
                        text: Media.album || Media.playerName
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.normal
                        elide: Text.ElideRight
                        opacity: 0.8
                    }

                    Item { width: 1; height: 32 }

                    Column {
                        width: parent.width
                        spacing: 7

                        Item {
                            id: seekTrack
                            width: parent.width
                            height: 18

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.surfaceHigh
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * Media.progress
                                height: 4
                                radius: 2
                                color: Theme.primary
                                Behavior on width { Anim { duration: 420; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, parent.width * Media.progress - width / 2))
                                width: 12
                                height: width
                                radius: width / 2
                                color: Theme.text
                                opacity: Media.canScrub ? 1 : 0
                                Behavior on x { Anim { duration: 420; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                                Behavior on opacity { Anim {} }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: Media.canScrub
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: event => Media.seekTo(Media.duration * Math.max(0, Math.min(1, event.x / width)))
                                onPositionChanged: event => {
                                    if (pressed) Media.seekTo(Media.duration * Math.max(0, Math.min(1, event.x / width)));
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            StyledText {
                                text: Media.positionText
                                color: Theme.textMuted
                                font.pixelSize: Theme.font.small
                                font.features: { "tnum": 1 }
                            }
                            Item { width: Math.max(0, parent.width - 88); height: 1 }
                            StyledText {
                                text: Media.durationText
                                color: Theme.textMuted
                                font.pixelSize: Theme.font.small
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    Item { width: 1; height: 18 }

                    Row {
                        spacing: 12

                        TransportButton {
                            icon: "shuffle"
                            small: true
                            available: Media.shuffleSupported
                            active: Media.shuffled
                            onClicked: Media.toggleShuffle()
                        }
                        TransportButton {
                            icon: "skip_previous"
                            available: Media.active?.canGoPrevious ?? false
                            onClicked: Media.previous()
                        }
                        TransportButton {
                            icon: "replay_10"
                            small: true
                            available: Media.canSeek
                            onClicked: Media.seekBy(-10)
                        }
                        TransportButton {
                            icon: Media.playing ? "pause" : "play_arrow"
                            primary: true
                            available: Media.active?.canTogglePlaying ?? false
                            onClicked: Media.togglePlaying()
                        }
                        TransportButton {
                            icon: "forward_10"
                            small: true
                            available: Media.canSeek
                            onClicked: Media.seekBy(10)
                        }
                        TransportButton {
                            icon: "skip_next"
                            available: Media.active?.canGoNext ?? false
                            onClicked: Media.next()
                        }
                    }

                    Item { width: 1; height: 20 }

                    StyledText {
                        text: Media.canScrub ? "DESLIZÁ PARA BUSCAR" : "CONTROLES DEL REPRODUCTOR"
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                        opacity: 0.7
                    }
                }
            }
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

        width: primary ? 58 : small ? 38 : 46
        height: width
        radius: Theme.radius.full
        color: primary ? Theme.primary : active ? Theme.groupActive : "transparent"
        opacity: available ? 1 : 0.4

        Behavior on color { CAnim {} }
        Behavior on scale { Anim { duration: Theme.anim.fast } }

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            color: button.primary ? Theme.textOnPrimary : button.active ? Theme.primary : Theme.text
            font.pixelSize: button.primary ? 28 : button.small ? 18 : 22
            animateChange: false
        }

        StateLayer {
            id: touch
            radius: Theme.radius.full
            disabled: !button.available
            color: button.primary ? Theme.textOnPrimary : Theme.text
            onClicked: button.clicked()
        }

        scale: touch.pressed && button.available ? 0.92 : 1
    }
}
