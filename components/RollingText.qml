pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

// Texto en el que cada carácter "rueda" verticalmente al cambiar,
// como un marcador mecánico. Ideal para el reloj.
Row {
    id: root

    property string text
    property color color: Theme.text
    property font font: Qt.font({ family: Theme.font.family, pixelSize: Theme.font.normal, weight: Font.Medium, features: { "tnum": 1 } })

    Repeater {
        model: root.text.length

        Item {
            id: cell

            required property int index
            readonly property string glyph: root.text.charAt(index)
            property string shown: glyph

            implicitWidth: Math.max(current.implicitWidth, metrics.width)
            implicitHeight: current.implicitHeight
            clip: true

            TextMetrics { id: metrics; font: root.font; text: cell.glyph }

            onGlyphChanged: {
                previous.text = shown;
                shown = glyph;
                roll.restart();
            }

            Text {
                id: previous
                color: root.color
                font: root.font
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0
            }

            Text {
                id: current
                text: cell.shown
                color: root.color
                font: root.font
                anchors.horizontalCenter: parent.horizontalCenter
            }

            ParallelAnimation {
                id: roll
                Anim { target: previous; property: "y"; from: 0; to: -cell.height; easing.bezierCurve: Theme.anim.emphasizedAccel }
                Anim { target: previous; property: "opacity"; from: 1; to: 0 }
                Anim { target: current; property: "y"; from: cell.height; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
                Anim { target: current; property: "opacity"; from: 0; to: 1 }
            }
        }
    }
}
