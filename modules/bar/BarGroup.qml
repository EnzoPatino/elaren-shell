import QtQuick
import "../../theme"
import "../../components"

// "Píldora" que agrupa widgets de la barra. Su ancho se anima cuando el
// contenido crece o se encoge, y entra con un retardo configurable.
StyledRect {
    id: root

    default property alias content: row.data
    property int padding: Theme.spacing.normal
    property bool revealed: true
    property int revealDelay: 0
    // Con `clickable`, todo el grupo actúa como botón (hover + ripple).
    property bool clickable: false

    signal clicked()

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.bar.itemHeight
    radius: Theme.radius.full
    color: Theme.surfaceContainer
    clip: true

    opacity: revealed ? 1 : 0
    transform: Translate {
        y: root.revealed ? 0 : -10
        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: root.revealDelay * Theme.anim.scale }
                Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
            }
        }
    }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.revealDelay * Theme.anim.scale }
            Anim { duration: Theme.anim.slow }
        }
    }
    Behavior on implicitWidth { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.emphasizedDecel } }

    Row {
        id: row
        x: root.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.small
    }

    StateLayer {
        visible: root.clickable
        radius: root.radius
        onClicked: root.clicked()
    }
}
