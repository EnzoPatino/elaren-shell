pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../config"
import "../../components"

// Selector de avatares dibujados: muestra el actual y una tanda de personajes
// generados al azar. Clic en uno para usarlo; "Mezclar" genera otra tanda.
// Cada personaje es una semilla (un texto), que es lo único que se guarda.
Item {
    id: root

    readonly property int thumb: 56
    readonly property int count: 11
    property list<string> seeds: []

    function shuffle(): void {
        const out = [];
        for (let i = 0; i < count; i++) out.push(Math.random().toString(36).slice(2, 10));
        seeds = out;
    }

    Component.onCompleted: shuffle()

    width: parent?.width ?? 0
    implicitHeight: flow.implicitHeight + Theme.spacing.large * 2

    Flow {
        id: flow

        x: Theme.spacing.large
        y: Theme.spacing.large
        width: parent.width - Theme.spacing.large * 2
        spacing: Theme.spacing.normal

        // El elegido primero, después la tanda al azar.
        Repeater {
            model: [Config.barAvatarSeed].concat(root.seeds.filter(s => s !== Config.barAvatarSeed))

            Item {
                id: item

                required property string modelData
                readonly property bool current: Config.barAvatarSeed === modelData

                width: root.thumb
                height: root.thumb

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: item.current ? Theme.primary : "transparent"

                    Behavior on border.color { CAnim {} }
                }

                Avatar {
                    anchors.fill: parent
                    shape: "circle"
                    source: "drawn"
                    seed: item.modelData
                    // Solo parpadea el elegido: una grilla entera parpadeando distrae.
                    animated: item.current
                    lookX: hover.hovered ? (hover.point.position.x / width - 0.5) * 2 : 0
                    lookY: hover.hovered ? (hover.point.position.y / height - 0.5) * 2 : 0
                    scale: touch.pressed ? 0.9 : touch.containsMouse ? 1.08 : 1

                    Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }

                    HoverHandler { id: hover }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.full
                    color: "transparent"
                    onClicked: Config.barAvatarSeed = item.modelData
                }
            }
        }

        // Mezclar: otra tanda de personajes
        Rectangle {
            width: root.thumb
            height: root.thumb
            radius: width / 2
            color: Qt.alpha(Theme.primary, 0.14)
            border.width: 1
            border.color: Qt.alpha(Theme.primary, 0.35)

            Column {
                anchors.centerIn: parent
                spacing: 0

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "shuffle"
                    font.pixelSize: 20
                    color: Theme.primary
                    animateChange: false
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Mezclar"
                    color: Theme.primary
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }

            StateLayer {
                radius: Theme.radius.full
                onClicked: root.shuffle()
            }
        }
    }
}
