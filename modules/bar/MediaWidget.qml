pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Reproductor actual (MPRIS). La carátula gira mientras suena y, al pasar
// el ratón, se despliegan los controles.
Reveal {
    id: root

    property bool revealed: true
    property int revealDelay: 0

    shown: Media.available && revealed

    BarGroup {
        id: group

        padding: Theme.spacing.small
        revealed: root.revealed
        revealDelay: root.revealDelay

        HoverHandler { id: hover }

        // Carátula (o nota musical si no hay)
        ClippingRectangle {
            id: disc
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: Theme.radius.full
            color: Theme.surfaceHigh

            MaterialIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "music_note"
                font.pixelSize: Theme.font.normal
                color: Theme.primary
            }

            Image {
                id: art
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(64, 64)
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity { Anim {} }
            }

            // Gira como un vinilo mientras suena; al pausar se queda quieta.
            FrameAnimation {
                running: Media.playing && Theme.anim.scale > 0
                onTriggered: disc.rotation = (disc.rotation + frameTime * 40) % 360
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, hover.hovered ? 220 : 140)
            elide: Text.ElideRight
            text: Media.artist ? `${Media.title} — ${Media.artist}` : Media.title
            animate: true
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: hover.hovered

            Row {
                spacing: 2

                Repeater {
                    model: [
                        { icon: "skip_previous", action: () => Media.previous() },
                        { icon: "", action: () => Media.togglePlaying() },
                        { icon: "skip_next", action: () => Media.next() }
                    ]

                    Rectangle {
                        id: button
                        required property var modelData
                        required property int index
                        width: 24
                        height: 24
                        radius: Theme.radius.full
                        color: index === 1 ? Theme.primary : "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: button.index === 1 ? (Media.playing ? "pause" : "play_arrow") : button.modelData.icon
                            color: button.index === 1 ? Theme.textOnPrimary : Theme.text
                        }

                        StateLayer { onClicked: button.modelData.action() }
                    }
                }
            }
        }
    }
}
