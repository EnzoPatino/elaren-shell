import QtQuick
import "../theme"

// Muestra u oculta su contenido animando el ancho, la escala y la opacidad.
// Cuando está oculto ocupa 0 px, así que no deja hueco en un Row.
//
// Se anima un `progress` de 0 a 1 en vez del ancho directamente: así, si el
// contenido cambia de tamaño mientras está visible, el ancho lo sigue al
// instante (y el propio hijo decide cómo animarlo).
Item {
    id: root

    property bool shown: true
    default property alias content: holder.data
    readonly property Item child: holder.children.length > 0 ? holder.children[0] : null
    property real progress: shown ? 1 : 0

    implicitWidth: (child?.implicitWidth ?? 0) * progress
    implicitHeight: child?.implicitHeight ?? 0
    visible: progress > 0.001
    opacity: progress
    clip: progress < 1

    Behavior on progress { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.emphasizedDecel } }

    Item {
        id: holder
        anchors.verticalCenter: parent.verticalCenter
        width: root.child?.implicitWidth ?? 0
        height: root.child?.implicitHeight ?? 0
        scale: root.shown ? 1 : 0.6
        transformOrigin: Item.Left

        Behavior on scale { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
    }
}
