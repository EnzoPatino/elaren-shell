import QtQuick
import "../../theme"
import "../../components"

// Fila con un campo de texto. `committed` se emite al apretar Enter o al
// salir del campo (no con cada tecla).
RowBase {
    id: root

    property string text
    property string placeholder
    signal committed(string value)

    Rectangle {
        width: 220
        height: 34
        radius: 10
        color: Qt.alpha(Theme.text, 0.06)
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.primary : Qt.alpha(Theme.text, 0.12)

        Behavior on border.color { CAnim {} }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            text: root.text
            color: Theme.text
            selectionColor: Qt.alpha(Theme.primary, 0.4)
            font.family: Theme.font.family
            font.pixelSize: Theme.font.normal
            clip: true

            onAccepted: {
                root.committed(text);
                focus = false;
            }
            onActiveFocusChanged: if (!activeFocus && text !== root.text) root.committed(text)

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text && !input.activeFocus
                text: root.placeholder
                color: Theme.textMuted
            }
        }
    }
}
