// ┌─ NO TOCAR ───────────────────────────────────────────────────────────┐
// │ Gestor de fondos del entorno Hyprland: Elaren dibuja el fondo y la   │
// │ pestaña Fondos de la isla lo cambia. Funciona y está terminado: no   │
// │ lo cambies, ni lo reemplaces ni lo "simplifiques" sin que el autor   │
// │ lo pida explícitamente.                                              │
// │ Archivos: services/Wallpaper.qml, modules/background/Background.qml  │
// │ y modules/bar/WallpaperView.qml.                                     │
// └──────────────────────────────────────────────────────────────────────┘

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import Quickshell.Widgets
import "../../theme"
import "../../components"
import "../../services"

// Vista "Fondos" de la isla: las imágenes de una carpeta como miniaturas.
// Clic o Enter: poner ese fondo (la isla queda abierta para probar otros).
// Flechas: moverse · Rueda: desplazar · Esc: cerrar la isla.
//
// Memoria: la vista vive solo con la isla abierta en esta pestaña, y cada
// miniatura se decodifica chica (nunca la imagen entera, que puede ser 8K).
Item {
    id: root

    signal dismissed()

    // La isla le devuelve el teclado al reabrirse (Island.focusView).
    readonly property bool wantsFocus: true
    onActiveFocusChanged: if (activeFocus) grid.forceActiveFocus()

    readonly property int columns: 4
    readonly property int thumbWidth: 150
    readonly property int thumbHeight: 88
    readonly property int gap: Theme.spacing.normal
    readonly property int maxRows: 3

    readonly property int cellWidth: thumbWidth + gap
    readonly property int cellHeight: thumbHeight + gap
    readonly property int rows: Math.min(maxRows, Math.ceil(images.count / columns))

    implicitWidth: columns * cellWidth - gap
    implicitHeight: header.height + Theme.spacing.normal
        + (images.count > 0 ? rows * cellHeight - gap : empty.implicitHeight + 40)

    FolderListModel {
        id: images

        folder: `file://${Wallpaper.folder}`
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        caseSensitive: false
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name

        // Al cargar la carpeta, arrancar parado sobre el fondo de ahora.
        onStatusChanged: if (status === FolderListModel.Ready) root.selectCurrent()
    }

    function selectCurrent(): void {
        const i = images.indexOf(`file://${Wallpaper.currentPath}`);
        grid.currentIndex = i >= 0 ? i : 0;
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }

    function applyAt(index: int): void {
        if (index < 0 || index >= images.count) return;
        Wallpaper.apply(images.get(index, "filePath"));
    }

    // ── Encabezado: carpeta y cantidad ───────────────────────────────────
    Row {
        id: header
        width: parent.width
        height: 22
        spacing: Theme.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "folder"
            color: Theme.textMuted
            font.pixelSize: Theme.font.icon
            animateChange: false
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.font.icon - count.implicitWidth - parent.spacing * 2
            text: Wallpaper.folder.replace(/^\/home\/[^/]+/, "~")
            color: Theme.textMuted
            elide: Text.ElideMiddle
        }

        StyledText {
            id: count
            anchors.verticalCenter: parent.verticalCenter
            text: images.count === 1 ? "1 imagen" : `${images.count} imágenes`
            color: Theme.textMuted
            font.pixelSize: Theme.font.small
        }
    }

    // ── Miniaturas ───────────────────────────────────────────────────────
    GridView {
        id: grid

        y: header.height + Theme.spacing.normal
        // Una columna de más en el ancho del área: la última celda no lleva
        // separación a la derecha.
        width: root.columns * root.cellWidth
        height: root.rows * root.cellHeight
        visible: images.count > 0
        clip: true
        model: images
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        focus: true
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false
        // Pocas filas fuera de la vista ya decodificadas: el scroll no
        // muestra huecos pero tampoco carga la carpeta entera.
        cacheBuffer: root.cellHeight * 2

        Component.onCompleted: forceActiveFocus()

        Keys.onReturnPressed: root.applyAt(currentIndex)
        Keys.onEnterPressed: root.applyAt(currentIndex)

        delegate: Item {
            id: cell

            required property int index
            required property string filePath
            required property url fileUrl
            required property string fileBaseName

            readonly property bool current: filePath === Wallpaper.currentPath
            readonly property bool selected: GridView.isCurrentItem && grid.activeFocus

            width: root.cellWidth
            height: root.cellHeight

            ClippingRectangle {
                id: frame

                width: root.thumbWidth
                height: root.thumbHeight
                radius: Theme.radius.normal
                color: Qt.alpha(Theme.text, 0.05)
                scale: touch.pressed ? 0.96 : 1

                Behavior on scale { Anim { duration: Theme.anim.fast } }

                Image {
                    id: thumb
                    anchors.fill: parent
                    source: cell.fileUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // Al doble del tamaño en pantalla como mucho: un 8K pesa
                    // lo mismo que un 1080p en la grilla.
                    sourceSize.width: Math.ceil(root.thumbWidth * Screen.devicePixelRatio)
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity { Anim { duration: Theme.anim.normal } }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: thumb.status === Image.Error
                    text: "broken_image"
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.icon
                    animateChange: false
                }

                // Nombre al pasar el ratón
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 22
                    color: Qt.alpha(Theme.surface, 0.72)
                    opacity: touch.containsMouse ? 1 : 0

                    Behavior on opacity { Anim { duration: Theme.anim.fast } }

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.small
                        anchors.rightMargin: Theme.spacing.small
                        verticalAlignment: Text.AlignVCenter
                        text: cell.fileBaseName
                        font.pixelSize: Theme.font.small
                        elide: Text.ElideRight
                    }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.normal
                    onClicked: {
                        grid.currentIndex = cell.index;
                        root.applyAt(cell.index);
                    }
                }
            }

            // Borde: el fondo puesto (acento) o la selección con teclado.
            Rectangle {
                anchors.fill: frame
                anchors.margins: -2
                radius: Theme.radius.normal + 2
                color: "transparent"
                border.width: 2
                border.color: cell.current ? Theme.primary : Qt.alpha(Theme.text, 0.6)
                visible: cell.current || cell.selected
            }

            Rectangle {
                anchors.right: frame.right
                anchors.top: frame.top
                anchors.margins: 6
                width: 20
                height: 20
                radius: 10
                visible: cell.current
                color: Theme.primary

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "check"
                    color: Theme.textOnPrimary
                    font.pixelSize: 14
                    animateChange: false
                }
            }
        }
    }

    // ── Carpeta vacía o inexistente ──────────────────────────────────────
    Column {
        id: empty

        y: header.height + Theme.spacing.normal + 20
        width: parent.width
        spacing: Theme.spacing.normal
        visible: images.count === 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "hide_image"
            color: Theme.textMuted
            font.pixelSize: 32
            animateChange: false
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "No hay imágenes en esta carpeta"
            color: Theme.textMuted
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: chooseLabel.implicitWidth + Theme.spacing.large * 2
            height: 32
            radius: Theme.radius.full
            color: Qt.alpha(Theme.primary, 0.2)

            StyledText {
                id: chooseLabel
                anchors.centerIn: parent
                text: "Elegir carpeta"
                color: Theme.text
                font.weight: Font.Medium
            }

            StateLayer {
                radius: Theme.radius.full
                onClicked: {
                    Settings.show("wallpaper");
                    root.dismissed();
                }
            }
        }
    }
}
