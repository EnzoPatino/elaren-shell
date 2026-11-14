pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Now playing: carátula viva, progreso escrutable y controles al pasar
// el ratón. La portada o el título abren el reproductor completo.
Reveal {
    id: root

    property bool revealed: true
    property int revealDelay: 0
    property bool popupOpen: false

    signal popupRequested()

    shown: Media.available && revealed

    BarGroup {
        id: group

        padding: Theme.spacing.small
        revealed: root.revealed
        revealDelay: root.revealDelay
        color: root.popupOpen ? Theme.groupActive : Theme.group

        HoverHandler { id: hover }

        Column {
            id: content
            spacing: 1

            Row {
                id: controlsRow
                spacing: Theme.spacing.small

                ClippingRectangle {
                    id: disc
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: Theme.radius.full
                    color: Theme.surfaceHigh
                    scale: Media.playing ? 1 : 0.94

                    Behavior on scale { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }

                    Image {
                        id: art
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(64, 64)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity { Anim {} }

                        NumberAnimation on rotation {
                            running: Media.playing && Theme.anim.scale > 0
                            from: 0
                            to: 360
                            duration: 9000 * Theme.anim.scale
                            loops: Animation.Infinite
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "music_note"
                        font.pixelSize: Theme.font.normal
                        color: Media.accent
                    }

                    // Un pequeño halo acompaña la reproducción sin competir
                    // con la carátula ni consumir un callback por frame.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Media.playing ? Qt.alpha(Media.accent, 0.85) : "transparent"
                        opacity: Media.playing ? 1 : 0.45

                        Behavior on border.color { CAnim {} }
                    }

                    StateLayer {
                        radius: Theme.radius.full
                        color: Theme.textOnPrimary
                        onClicked: root.popupRequested()
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, hover.hovered ? 190 : 112)
                    elide: Text.ElideRight
                    text: Media.artist ? `${Media.title} · ${Media.artist}` : Media.title
                    color: Media.playing ? Theme.text : Theme.textMuted
                    font.weight: Media.playing ? Font.Medium : Font.Normal
                    animate: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.popupRequested()
                    }
                }

                Reveal {
                    anchors.verticalCenter: parent.verticalCenter
                    shown: hover.hovered && Media.hasProgress

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Media.positionText} / ${Media.durationText}`
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                        font.features: { "tnum": 1 }
                    }
                }

                Reveal {
                    anchors.verticalCenter: parent.verticalCenter
                    shown: hover.hovered

                    Row {
                        spacing: 1

                        Repeater {
                            model: [
                                { icon: "skip_previous", action: () => Media.previous(), enabled: Media.active?.canGoPrevious ?? false },
                                { icon: Media.playing ? "pause" : "play_arrow", action: () => Media.togglePlaying(), enabled: Media.active?.canTogglePlaying ?? false },
                                { icon: "skip_next", action: () => Media.next(), enabled: Media.active?.canGoNext ?? false }
                            ]

                            Rectangle {
                                id: button
                                required property var modelData
                                required property int index
                                width: 23
                                height: 24
                                radius: Theme.radius.full
                                color: index === 1 ? Theme.primary : "transparent"
                                opacity: button.modelData.enabled ? 1 : 0.42

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: button.modelData.icon
                                    color: button.index === 1 ? Theme.textOnPrimary : Theme.text
                                    animateChange: false
                                }

                                StateLayer {
                                    disabled: !button.modelData.enabled
                                    color: button.index === 1 ? Theme.textOnPrimary : Theme.text
                                    radius: Theme.radius.full
                                    onClicked: button.modelData.action()
                                }
                            }
                        }
                    }
                }

                Reveal {
                    anchors.verticalCenter: parent.verticalCenter
                    shown: hover.hovered

                    Rectangle {
                        width: 22
                        height: 24
                        radius: Theme.radius.full
                        color: "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "open_in_full"
                            color: root.popupOpen ? Theme.primary : Theme.textMuted
                            animateChange: false
                        }

                        StateLayer {
                            radius: Theme.radius.full
                            onClicked: root.popupRequested()
                        }
                    }
                }
            }

            Item {
                id: timeline
                width: controlsRow.implicitWidth
                height: 3
                visible: Media.hasProgress

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Theme.surfaceHigh
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Media.progress
                    height: 2
                    radius: 1
                    color: Media.playing ? Media.accent : Theme.textMuted

                    Behavior on width { Anim { duration: 420; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                    Behavior on color { CAnim {} }
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
        }
    }
}
