pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Detalle del tema actual: arte, álbum, reproductor, progreso y transporte.
AnimatedPopup {
    id: root

    cardWidth: 324

    component TransportButton: Rectangle {
        id: control

        property string icon
        property bool primary: false
        property bool available: true
        signal clicked()

        width: primary ? 44 : 36
        height: width
        radius: Theme.radius.full
        color: primary ? Theme.primary : Theme.surfaceContainer
        opacity: available ? 1 : 0.42

        MaterialIcon {
            anchors.centerIn: parent
            text: control.icon
            color: control.primary ? Theme.textOnPrimary : Theme.text
            font.pixelSize: control.primary ? Theme.font.large : Theme.font.normal
            animateChange: false
        }

        StateLayer {
            radius: Theme.radius.full
            disabled: !control.available
            color: control.primary ? Theme.textOnPrimary : Theme.text
            onClicked: control.clicked()
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacing.normal

        Row {
            width: parent.width
            spacing: Theme.spacing.normal

            ClippingRectangle {
                width: 84
                height: 84
                radius: Theme.radius.normal
                color: Theme.surfaceHigh

                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(192, 192)
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { Anim {} }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "album"
                    font.pixelSize: 30
                    color: Theme.primary
                }
            }

            Column {
                width: parent.width - 84 - Theme.spacing.normal - 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                StyledText {
                    width: parent.width
                    text: Media.playing ? "REPRODUCIENDO" : "EN PAUSA"
                    color: Media.playing ? Theme.primary : Theme.textMuted
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }

                StyledText {
                    width: parent.width
                    text: Media.title
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.large
                    font.weight: Font.DemiBold
                    animate: true
                }

                StyledText {
                    width: parent.width
                    text: Media.artist || "Artista desconocido"
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    animate: true
                }

                StyledText {
                    width: parent.width
                    text: Media.album || Media.playerName
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                }
            }

            Rectangle {
                width: 24
                height: 24
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

        Column {
            id: trackDetails
            width: parent.width
            spacing: 4
            visible: Media.hasProgress

            Item {
                id: track
                width: parent.width
                height: 12

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
                Item { width: Math.max(0, parent.width - 90); height: 1 }
                StyledText {
                    text: Media.durationText
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                    font.features: { "tnum": 1 }
                }
            }
        }

        Row {
            x: (parent.width - implicitWidth) / 2
            spacing: Theme.spacing.normal

            TransportButton {
                icon: "skip_previous"
                available: Media.active?.canGoPrevious ?? false
                onClicked: Media.previous()
            }
            TransportButton {
                icon: "replay_10"
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
                available: Media.canSeek
                onClicked: Media.seekBy(10)
            }
            TransportButton {
                icon: "skip_next"
                available: Media.active?.canGoNext ?? false
                onClicked: Media.next()
            }
        }
    }
}
