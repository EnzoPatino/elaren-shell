import QtQuick
import "../theme"

// Deja derecho un texto (u otra pieza no cuadrada) dentro de la barra girada
// de los costados: gira el contenido Theme.bar.upright grados e intercambia
// ancho y alto, así el lugar que ocupa a lo largo de la barra es su alto.
// En la barra horizontal no hace nada.
Item {
    id: root

    default property alias content: holder.data
    readonly property Item child: holder.children.length > 0 ? holder.children[0] : null
    readonly property bool turned: Theme.bar.vertical

    implicitWidth: turned ? (child?.height ?? 0) : (child?.width ?? 0)
    implicitHeight: turned ? (child?.width ?? 0) : (child?.height ?? 0)

    Item {
        id: holder
        anchors.centerIn: parent
        width: root.child?.width ?? 0
        height: root.child?.height ?? 0
        rotation: Theme.bar.upright
    }
}
