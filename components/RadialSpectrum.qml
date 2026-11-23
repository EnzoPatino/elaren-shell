pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

// Espectro de audio en anillo, alrededor de un disco. Como SpectrumView, no
// calcula nada: recibe los valores (0..1) ya suavizados (Visualizer.display).
// El espectro va espejado (graves arriba, agudos abajo, igual a los dos
// lados) para que el anillo no tenga un "salto" donde se juntan los extremos.
//
// Costo: `count` rectángulos que solo cambian de alto. Los valores se copian
// a un array de JS una vez por cuadro (indexar una `list<real>` la copia
// entera en cada acceso). Con `active` en falso no se reevalúa nada.
Item {
    id: root

    property var values: []
    property bool active: true
    property int count: 48
    // Radio donde nacen las barras y cuánto pueden crecer hacia afuera.
    property real innerRadius: Math.min(width, height) * 0.36
    property real reach: Math.min(width, height) * 0.12
    property real thickness: Math.max(2, innerRadius * 2 * Math.PI / count * 0.42)
    property color color: Theme.primary

    readonly property var samples: active ? Array.from(values ?? []) : []
    readonly property int sampleCount: samples.length

    Repeater {
        model: root.count

        Item {
            id: spoke

            required property int index
            // 0 arriba, 1 abajo, a los dos lados.
            readonly property real fold: 1 - Math.abs(1 - 2 * index / root.count)
            readonly property real value: root.sampleCount > 0
                ? Math.min(1, root.samples[Math.min(root.sampleCount - 1, Math.floor(fold * root.sampleCount))] ?? 0)
                : 0

            anchors.fill: parent
            rotation: index * 360 / root.count

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.thickness
                height: root.thickness + root.reach * spoke.value
                y: parent.height / 2 - root.innerRadius - height
                radius: width / 2
                color: root.color
                opacity: 0.35 + 0.65 * spoke.value
            }
        }
    }
}
