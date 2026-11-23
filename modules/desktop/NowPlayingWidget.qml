pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Tarjeta de música para el escritorio: portada, tema, progreso, controles
// y un mini-espectro que sigue la música.
//
// Con Config.widgetMediaMode === "lyrics" muestra solo la letra sincronizada,
// que se desliza línea a línea. Mientras se busca, o si LRCLIB no tiene la
// letra sincronizada, vuelve a la tarjeta normal.
DesktopWidget {
    id: root

    key: "Media"

    readonly property color accent: Media.accent
    readonly property bool showLyrics: Config.widgetMediaMode === "lyrics"
        && Lyrics.status === "found" && Lyrics.synced

    Loader {
        sourceComponent: root.showLyrics ? lyricsView : playerView
    }

    Component {
        id: playerView

        Row {
            spacing: 16

            // Portada con halo del color del disco
            Item {
                width: 96
                height: 96

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 10 + Visualizer.level * 10
                    height: width
                    radius: 26
                    color: Qt.alpha(root.accent, 0.18 + Visualizer.level * 0.2)
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 20
                    color: Qt.darker(root.accent, 2.5)

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(192, 192)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity { Anim { duration: Theme.anim.slow } }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "album"
                        font.pixelSize: 44
                        color: root.accent
                    }
                }

                // Clic en la portada: pausa / reanuda
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.togglePlaying()
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 250
                spacing: 4

                Row {
                    spacing: 6

                    MiniSpectrum {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (Media.playing ? "SONANDO" : "EN PAUSA") + " · " + Media.playerName.toUpperCase()
                        color: root.accent
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }
                }

                StyledText {
                    width: parent.width
                    text: Media.title
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    animate: true
                }
                StyledText {
                    width: parent.width
                    text: Media.artist || "Artista desconocido"
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    animate: true
                }

                // Progreso
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.15)
                    visible: Media.hasProgress

                    Rectangle {
                        width: parent.width * Media.progress
                        height: parent.height
                        radius: 2
                        color: root.accent

                        Behavior on width { Anim { duration: 450 } }
                    }
                }

                // Controles
                Row {
                    spacing: 6
                    topPadding: 2

                    Repeater {
                        model: [
                            { icon: "skip_previous", action: () => Media.previous() },
                            { icon: "", action: () => Media.togglePlaying() },
                            { icon: "skip_next", action: () => Media.next() }
                        ]

                        Rectangle {
                            id: control
                            required property var modelData
                            required property int index
                            readonly property bool main: index === 1

                            width: main ? 36 : 30
                            height: width
                            radius: width / 2
                            color: main ? root.accent : Qt.alpha(Theme.text, 0.08)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: control.main ? (Media.playing ? "pause" : "play_arrow") : control.modelData.icon
                                color: control.main ? "#14151b" : Theme.text
                                font.pixelSize: control.main ? 22 : 18
                            }

                            StateLayer {
                                radius: control.width / 2
                                onClicked: control.modelData.action()
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: lyricsView

        // Toda la letra en una columna que se desliza para dejar la línea
        // que suena a la altura de `focusY`. Las demás se achican y se
        // desvanecen según lo lejos que estén, así el salto entre líneas es
        // un desplazamiento suave y no un cambio de texto seco.
        Item {
            id: viewport

            readonly property int focusY: 78
            readonly property Item focused: {
                repeater.count;
                return repeater.itemAt(Math.max(0, Lyrics.currentIndex));
            }

            implicitWidth: 560
            implicitHeight: 190
            width: 560
            height: 190
            clip: true

            Column {
                id: lines

                width: parent.width
                spacing: 6
                y: viewport.focused ? viewport.focusY - viewport.focused.y - viewport.focused.height / 2 : 0

                Behavior on y { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.expressive } }

                Repeater {
                    id: repeater
                    model: Lyrics.lines

                    // El alto sigue a la escala: al crecer la línea que suena,
                    // empuja a las demás de a poco en vez de dejar huecos.
                    Item {
                        id: line

                        required property var modelData
                        required property int index
                        readonly property bool current: index === Lyrics.currentIndex
                        readonly property int distance: Math.abs(index - Math.max(0, Lyrics.currentIndex))

                        width: lines.width
                        height: label.implicitHeight * label.scale
                        opacity: current ? 1
                            : distance === 1 ? (index < Lyrics.currentIndex ? 0.35 : 0.6)
                            : distance === 2 ? 0.18
                            : 0

                        Behavior on opacity { Anim { duration: Theme.anim.slow } }

                        StyledText {
                            id: label

                            width: parent.width / scale
                            transformOrigin: Item.TopLeft
                            text: line.modelData.text || "♪"
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.pixelSize: 26
                            font.weight: Font.Bold
                            color: line.current ? root.accent : Theme.text
                            scale: line.current ? 1 : 0.62

                            Behavior on scale { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
                        }
                    }
                }
            }
        }
    }

    // Mini-espectro en vivo
    component MiniSpectrum: Row {
        spacing: 2
        height: 14

        Repeater {
            model: 5

            Rectangle {
                required property int index
                readonly property real value: Media.playing
                    ? (Visualizer.display[Math.floor((index + 0.5) * Visualizer.display.length / 5)] ?? Visualizer.level)
                    : 0
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                height: 3 + 11 * Math.min(1, value)
                color: root.accent
            }
        }
    }
}
