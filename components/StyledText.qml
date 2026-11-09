import QtQuick
import "../theme"

// Texto con la tipografía del tema. Con `animate`, los cambios de texto
// hacen un fundido corto en vez de saltar.
Text {
    id: root

    property bool animate: false

    color: Theme.text
    font.family: Theme.font.family
    font.pixelSize: Theme.font.normal
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    Behavior on color { CAnim {} }

    Behavior on text {
        enabled: root.animate
        SequentialAnimation {
            Anim { target: root; property: "opacity"; to: 0; duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.emphasizedAccel }
            PropertyAction {}
            Anim { target: root; property: "opacity"; to: 1; duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.emphasizedDecel }
        }
    }
}
