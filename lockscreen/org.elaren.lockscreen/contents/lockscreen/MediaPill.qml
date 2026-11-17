import QtQuick
import QtQuick.Effects
import org.kde.plasma.private.mpris as Mpris

// Lo que está sonando, con anterior / reproducir-pausa / siguiente.
// Se carga aparte para que, si falta el módulo MPRIS de Plasma, la pantalla
// de bloqueo funcione igual.
Item {
    id: root

    property color accent
    property color accentOn
    property color text
    property color textMuted
    property color glass
    property color glassBorder
    property string fontFamily
    property string iconFont

    implicitHeight: players.count > 0 ? 64 : 0
    height: implicitHeight

    Repeater {
        id: players
        model: Mpris.MultiplexerModel {}

        Rectangle {
            id: pill

            required property var model

            readonly property bool playing: model.playbackStatus === Mpris.PlaybackStatus.Playing

            width: root.width
            height: 64
            radius: 22
            color: root.glass
            border.color: root.glassBorder
            border.width: 1
            enabled: model.canControl

            Item {
                id: cover
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.alpha(root.accent, 0.2)

                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "music_note"
                        color: root.accent
                        font.family: root.iconFont
                        font.pixelSize: 22
                    }
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: pill.model.artUrl ?? ""
                    sourceSize: Qt.size(88, 88)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: 12
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: art.status === Image.Ready
                    source: art
                    maskEnabled: true
                    maskSource: coverMask
                }
            }

            Column {
                anchors.left: cover.right
                anchors.leftMargin: 12
                anchors.right: controls.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: pill.model.track || "Sin título"
                    color: root.text
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: pill.model.artist || pill.model.identity || ""
                    color: root.textMuted
                    font.family: root.fontFamily
                    font.pixelSize: 12
                }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                MediaButton {
                    icon: "skip_previous"
                    enabled: pill.model.canGoPrevious
                    onClicked: pill.model.container.Previous()
                }
                MediaButton {
                    icon: pill.playing ? "pause" : "play_arrow"
                    filled: true
                    onClicked: pill.model.container.PlayPause()
                }
                MediaButton {
                    icon: "skip_next"
                    enabled: pill.model.canGoNext
                    onClicked: pill.model.container.Next()
                }
            }
        }
    }

    component MediaButton: Rectangle {
        id: button

        property string icon
        property bool filled: false
        signal clicked()

        width: 38
        height: 38
        radius: 19
        color: filled ? root.accent : touch.containsMouse ? Qt.alpha("white", 0.08) : "transparent"
        opacity: enabled ? 1 : 0.4
        scale: touch.pressed ? 0.88 : 1

        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.filled ? root.accentOn : root.text
            font.family: root.iconFont
            font.pixelSize: 22
        }

        MouseArea {
            id: touch
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
