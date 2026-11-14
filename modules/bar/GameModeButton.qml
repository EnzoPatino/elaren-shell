import QtQuick
import "../../theme"
import "../../components"

// Modo gaming (beta, todavía no disponible): el botón está para ir viendo
// dónde va, pero no hace nada. Al pasar el ratón avisa que llega pronto.
// La propuesta con las alternativas está en docs/propuesta-modo-gaming.md.
BarGroup {
    id: root

    padding: Theme.spacing.normal
    opacity: hover.hovered ? 0.8 : 0.5

    Behavior on opacity { Anim { duration: Theme.anim.fast } }

    HoverHandler {
        id: hover
        cursorShape: Qt.ForbiddenCursor
    }

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: "sports_esports"
        font.pixelSize: Theme.font.icon
        color: Theme.textMuted
        animateChange: false
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: beta.implicitWidth + 8
        height: 14
        radius: 7
        color: Qt.alpha(Theme.warning, 0.18)

        StyledText {
            id: beta
            anchors.centerIn: parent
            text: "BETA"
            color: Theme.warning
            font.pixelSize: 8
            font.weight: Font.Bold
            font.letterSpacing: 0.8
        }
    }

    // Aviso al pasar el ratón
    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: hover.hovered

        StyledText {
            leftPadding: 2
            text: "Pronto"
            color: Theme.textMuted
            font.pixelSize: Theme.font.small
        }
    }
}
