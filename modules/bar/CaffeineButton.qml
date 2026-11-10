import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Botón "cafeína": impide que la pantalla se apague o se bloquee.
// Activo, la taza se tiñe y le sale vapor.
Item {
    id: root

    implicitWidth: 24
    implicitHeight: 24

    MaterialIcon {
        id: cup
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: "coffee"
        font.pixelSize: Theme.font.icon - 1
        color: Caffeine.enabled ? Theme.warning : Theme.textMuted
        scale: touch.pressed ? 0.8 : 1

        Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }
    }

    // Vapor: tres hilos que suben y se desvanecen, desfasados
    Repeater {
        model: 3

        Rectangle {
            id: steam

            required property int index

            x: root.width / 2 - 4 + index * 3
            y: 4
            width: 1.5
            height: 4
            radius: 1
            color: Theme.warning
            opacity: 0
            visible: Caffeine.enabled

            SequentialAnimation on y {
                running: Caffeine.enabled && Theme.anim.scale > 0
                loops: Animation.Infinite
                PauseAnimation { duration: steam.index * 260 }
                NumberAnimation { from: 5; to: -2; duration: 900; easing.type: Easing.OutSine }
            }
            SequentialAnimation on opacity {
                running: Caffeine.enabled && Theme.anim.scale > 0
                loops: Animation.Infinite
                PauseAnimation { duration: steam.index * 260 }
                NumberAnimation { from: 0.9; to: 0; duration: 900 }
            }
        }
    }

    StateLayer {
        id: touch
        radius: Theme.radius.full
        onClicked: Caffeine.toggle()
    }
}
