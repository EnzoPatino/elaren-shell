pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import "../../theme"
import "../../config"
import "../../components"

// Galería de los avatares que trae Plasma (/usr/share/plasma/avatars): los
// Konqi y las fotos ilustradas. Clic en uno para usarlo en la barra.
Item {
    id: root

    readonly property int thumb: 52

    width: parent?.width ?? 0
    implicitHeight: flow.implicitHeight + Theme.spacing.large * 2

    FolderListModel {
        id: konqis
        folder: "file:///usr/share/plasma/avatars"
        nameFilters: ["*.png", "*.jpg", "*.svg"]
        showDirs: false
    }

    FolderListModel {
        id: photos
        folder: "file:///usr/share/plasma/avatars/photos"
        nameFilters: ["*.png", "*.jpg", "*.svg"]
        showDirs: false
    }

    Flow {
        id: flow

        x: Theme.spacing.large
        y: Theme.spacing.large
        width: parent.width - Theme.spacing.large * 2
        spacing: Theme.spacing.normal

        Repeater { model: konqis; delegate: thumbnail }
        Repeater { model: photos; delegate: thumbnail }
    }

    Component {
        id: thumbnail

        Item {
            id: item

            required property string filePath
            required property string fileBaseName
            readonly property bool current: Config.barAvatarImage === filePath

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
                source: "plasma"
                path: item.filePath
                scale: touch.pressed ? 0.9 : touch.containsMouse ? 1.08 : 1

                Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }
            }

            StateLayer {
                id: touch
                radius: Theme.radius.full
                color: "transparent"
                onClicked: Config.barAvatarImage = item.filePath
            }
        }
    }
}
