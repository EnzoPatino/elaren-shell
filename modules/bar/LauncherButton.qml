import QtQuick
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Botón de aplicaciones: píldora con degradado que abre el lanzador.
// Al pasar el ratón muestra la etiqueta; con el lanzador abierto el icono
// gira y se convierte en una cruz.
Rectangle {
    id: root

    property bool revealed: true
    readonly property bool active: AppLauncher.open

    implicitWidth: content.implicitWidth + 20
    implicitHeight: Theme.bar.itemHeight
    radius: Theme.radius.full
    clip: true

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.primary }
        GradientStop { position: 1; color: Theme.secondary }
    }

    scale: revealed ? (touch.pressed ? 0.92 : 1) : 0
    Behavior on scale { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast } }
    Behavior on implicitWidth { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel } }

    // Brillo que se intensifica con el hover
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "white"
        opacity: touch.containsMouse ? 0.18 : 0

        Behavior on opacity { Anim { duration: Theme.anim.fast } }
    }

    // Destello que cruza la píldora una vez al entrar el ratón (no queda
    // ninguna animación corriendo después), recortado a sus esquinas.
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Rectangle {
            id: shine
            y: -parent.height
            width: parent.height * 0.9
            height: parent.height * 3
            rotation: 20
            x: -width * 2
            opacity: 0.55
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.alpha("white", 0.55) }
                GradientStop { position: 1; color: "transparent" }
            }

            Anim {
                id: shineAnim
                target: shine
                property: "x"
                from: -shine.width * 2
                to: root.width + shine.width
                duration: Theme.anim.extraSlow
                easing.bezierCurve: Theme.anim.emphasizedDecel
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.active ? "close" : "apps"
            color: Theme.textOnPrimary
            font.pixelSize: Theme.font.icon
            rotation: root.active ? 90 : 0

            Behavior on rotation { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
        }

        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: touch.containsMouse || root.active

            StyledText {
                text: "Apps"
                color: Theme.textOnPrimary
                font.weight: Font.Bold
            }
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse && Theme.anim.scale > 0) shineAnim.restart()
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // Clic izquierdo: lanzador. Clic derecho: Configuración.
        onClicked: event => event.button === Qt.RightButton ? Settings.toggle() : AppLauncher.toggle()
    }
}
