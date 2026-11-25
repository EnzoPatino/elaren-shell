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
import QtQuick.Shapes
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Vista "Fondos" de la isla: carpeta por carpeta, con sus subcarpetas y sus
// fondos (imágenes y, si quien dibuja el fondo puede, videos). Lo de una
// subcarpeta no se mezcla con lo de afuera. Las raíces son la carpeta de
// Configuración → Fondo y, con skwd-wall, las de su biblioteca.
// Clic o Enter: entrar a la carpeta o poner ese fondo (la isla queda
// abierta para probar otros). Retroceso: subir. Flechas: moverse.
// Rueda: desplazar. Esc: cerrar la isla.
//
// Rendimiento: la vista vive solo con la isla abierta en esta pestaña; cada
// miniatura se decodifica chica (la de skwd-wall si existe) y se redondea
// con una forma rellena con la imagen, sin texturas intermedias.
Item {
    id: root

    signal dismissed()

    // La isla le devuelve el teclado al reabrirse (Island.focusView).
    readonly property bool wantsFocus: true
    onActiveFocusChanged: if (activeFocus) grid.forceActiveFocus()

    readonly property int columns: 4
    readonly property int thumbWidth: 216
    readonly property int thumbHeight: 122
    readonly property int gap: Theme.spacing.normal
    readonly property int maxRows: 3

    readonly property int cellWidth: thumbWidth + gap
    readonly property int cellHeight: thumbHeight + gap
    readonly property var items: Wallpaper.entries
    readonly property int rows: Math.max(1, Math.min(maxRows, Math.ceil(items.length / columns)))
    readonly property int wallpaperCount: items.filter(e => e.kind !== "folder").length

    implicitWidth: columns * cellWidth - gap
    implicitHeight: header.height + Theme.spacing.normal
        + (items.length > 0 ? rows * cellHeight - gap : empty.implicitHeight + 40)
        + (transitionsRow.visible ? transitionsRow.height + Theme.spacing.normal : 0)

    // Vuelve a la última carpeta abierta (releída por si cambió).
    Component.onCompleted: Wallpaper.browse(Wallpaper.browseDir)
    // Con la grilla ya armada (el modelo recién cambiado todavía no la llenó).
    onItemsChanged: Qt.callLater(selectCurrent)

    function selectCurrent(): void {
        // El fondo puesto o, si está en una subcarpeta, esa carpeta.
        const cur = Wallpaper.currentPath;
        let i = items.findIndex(e => e.path === cur);
        if (i < 0) i = items.findIndex(e => e.kind === "folder" && cur.startsWith(e.path + "/"));
        grid.currentIndex = i >= 0 ? i : 0;
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }

    function activate(index: int): void {
        const e = items[index];
        if (!e) return;
        if (e.kind === "folder") Wallpaper.browse(e.path);
        else Wallpaper.apply(e.path);
    }

    // Ruta de la carpeta abierta para el encabezado: desde su raíz.
    readonly property string location: {
        const dir = Wallpaper.browseDir;
        if (Wallpaper.atRoot) return Wallpaper.roots.length === 1 ? Wallpaper.baseName(Wallpaper.roots[0]) : "Fondos";
        if (dir === "@scenes") return "Escenas de Wallpaper Engine";
        const root = Wallpaper.roots.find(r => dir === r || dir.startsWith(r + "/")) ?? "";
        return root ? (Wallpaper.baseName(root) + dir.slice(root.length)).split("/").join("  ›  ") : dir;
    }

    // ── Encabezado: atrás, ubicación y cantidad ──────────────────────────
    Item {
        id: header
        width: parent.width
        height: 28

        Rectangle {
            id: back
            width: Wallpaper.atRoot ? 0 : 28
            height: 28
            radius: Theme.radius.full
            color: Qt.alpha(Theme.text, 0.06)
            opacity: Wallpaper.atRoot ? 0 : 1
            visible: width > 0

            Behavior on width { Anim { duration: Theme.anim.fast } }
            Behavior on opacity { Anim { duration: Theme.anim.fast } }

            MaterialIcon {
                anchors.centerIn: parent
                text: "arrow_back"
                font.pixelSize: Theme.font.normal + 3
                animateChange: false
            }

            StateLayer {
                radius: Theme.radius.full
                onClicked: Wallpaper.up()
            }
        }

        MaterialIcon {
            id: originIcon
            anchors.left: back.right
            anchors.leftMargin: back.width > 0 ? Theme.spacing.normal : 0
            anchors.verticalCenter: parent.verticalCenter
            text: Wallpaper.atRoot ? "photo_library" : "folder_open"
            color: Theme.textMuted
            font.pixelSize: Theme.font.icon
            animateChange: false
        }

        StyledText {
            anchors.left: originIcon.right
            anchors.leftMargin: Theme.spacing.small
            anchors.right: count.left
            anchors.rightMargin: Theme.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            text: root.location
            color: Theme.text
            font.weight: Font.Medium
            elide: Text.ElideLeft
        }

        StyledText {
            id: count
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.wallpaperCount === 1 ? "1 fondo" : root.wallpaperCount > 0 ? `${root.wallpaperCount} fondos` : ""
            color: Theme.textMuted
            font.pixelSize: Theme.font.small
        }
    }

    // Miniatura redondeada: una forma rellena con la imagen (recortada para
    // cubrir el marco). Más liviano que ClippingRectangle, que dibuja cada
    // celda en dos texturas intermedias y le pasa un shader.
    component Thumb: Item {
        id: thumb

        property string source
        property real radius: Theme.radius.normal
        readonly property int status: img.status

        Image {
            id: img
            visible: false
            source: thumb.source
            asynchronous: true
            cache: true
            // Al tamaño en pantalla: un 8K pesa lo mismo que un 1080p en la grilla.
            sourceSize.width: Math.ceil(root.thumbWidth * Screen.devicePixelRatio)
            readonly property real k: implicitWidth > 0 && implicitHeight > 0
                ? Math.max(thumb.width / implicitWidth, thumb.height / implicitHeight) : 1
            width: implicitWidth * k
            height: implicitHeight * k
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: img.status === Image.Ready ? 1 : 0

            Behavior on opacity { Anim { duration: Theme.anim.normal } }

            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillItem: img
                fillTransform: PlanarTransform.fromTranslate((thumb.width - img.width) / 2, (thumb.height - img.height) / 2)

                PathRectangle {
                    width: thumb.width
                    height: thumb.height
                    radius: thumb.radius
                }
            }
        }
    }

    // Botón chico con ícono y texto (filtros y transiciones).
    component Chip: Rectangle {
        id: chip

        property string icon
        property string label
        property bool selected
        signal clicked()

        width: chipRow.implicitWidth + Theme.spacing.large * 2
        height: 28
        radius: Theme.radius.full
        color: selected ? Qt.alpha(Theme.primary, 0.25) : Qt.alpha(Theme.text, 0.05)
        border.width: 1
        border.color: selected ? Qt.alpha(Theme.primary, 0.6) : "transparent"

        Behavior on color { CAnim { duration: Theme.anim.fast } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                font.pixelSize: Theme.font.normal + 2
                color: chip.selected ? Theme.primary : Theme.textMuted
                animateChange: false
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.pixelSize: Theme.font.small
                font.weight: chip.selected ? Font.DemiBold : Font.Normal
                color: chip.selected ? Theme.text : Theme.textMuted
            }
        }

        StateLayer {
            radius: Theme.radius.full
            onClicked: chip.clicked()
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
        visible: root.items.length > 0
        clip: true
        model: root.items
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        focus: true
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false
        // Una fila fuera de la vista ya decodificada: el scroll no muestra
        // huecos pero tampoco carga la carpeta entera.
        cacheBuffer: root.cellHeight
        reuseItems: true

        Component.onCompleted: forceActiveFocus()

        Keys.onReturnPressed: root.activate(currentIndex)
        Keys.onEnterPressed: root.activate(currentIndex)
        Keys.onBackPressed: Wallpaper.up()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace || (event.key === Qt.Key_Left && event.modifiers & Qt.AltModifier)) {
                Wallpaper.up();
                event.accepted = true;
            }
        }

        delegate: Item {
            id: cell

            required property int index
            required property var modelData

            readonly property bool isFolder: modelData.kind === "folder"
            readonly property bool current: modelData.path === Wallpaper.currentPath
            readonly property bool selected: GridView.isCurrentItem && grid.activeFocus
            readonly property bool animated: modelData.kind === "video" || modelData.kind === "scene"
            readonly property string thumbPath: isFolder ? modelData.cover
                : modelData.kind === "scene" ? (Wallpaper.skwdIndex[modelData.path]?.thumb ?? "")
                : Wallpaper.thumbFor(modelData.path)
            // Miniaturas propias de videos: se recargan al terminar de generarse.
            readonly property string thumbUrl: {
                if (!thumbPath) return "";
                const url = Wallpaper.toUrl(thumbPath);
                return thumbPath.startsWith(Wallpaper.thumbDir) ? `${url}?v=${Wallpaper.thumbsVersion}` : url;
            }

            width: root.cellWidth
            height: root.cellHeight

            Item {
                id: frame

                width: root.thumbWidth
                height: root.thumbHeight
                scale: touch.pressed ? 0.96 : touch.containsMouse ? 1.03 : 1

                Behavior on scale { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast } }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius.normal
                    color: Qt.alpha(Theme.text, 0.05)
                    visible: thumb.status !== Image.Ready || cell.isFolder
                }

                Thumb {
                    id: thumb
                    anchors.fill: parent
                    source: cell.thumbUrl
                    // Las carpetas muestran su tapa más chica y apagada.
                    opacity: cell.isFolder ? 0.45 : 1
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !cell.isFolder && thumb.status !== Image.Ready
                    text: thumb.status === Image.Error ? (cell.animated ? "movie" : "broken_image") : "image"
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.icon
                    animateChange: false
                }

                // Carpeta: ícono, nombre y cantidad
                Column {
                    visible: cell.isFolder
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing.large
                    spacing: 2

                    MaterialIcon {
                        text: cell.modelData.path === "@scenes" ? "auto_awesome" : "folder"
                        font.pixelSize: 26
                        color: Theme.primary
                        animateChange: false
                    }

                    StyledText {
                        width: parent.width
                        text: cell.modelData.name
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: cell.modelData.count >= 0
                        text: cell.modelData.count === 1 ? "1 fondo" : `${cell.modelData.count} fondos`
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                    }
                }

                // Nombre al pasar el ratón
                Rectangle {
                    visible: !cell.isFolder
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 24
                    bottomLeftRadius: Theme.radius.normal
                    bottomRightRadius: Theme.radius.normal
                    color: Qt.alpha(Theme.surface, 0.72)
                    opacity: touch.containsMouse ? 1 : 0

                    Behavior on opacity { Anim { duration: Theme.anim.fast } }

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.normal
                        anchors.rightMargin: Theme.spacing.normal
                        verticalAlignment: Text.AlignVCenter
                        text: cell.modelData.name
                        font.pixelSize: Theme.font.small
                        elide: Text.ElideRight
                    }
                }

                // Marca de fondo animado (video o escena)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 6
                    visible: cell.animated
                    width: kindRow.implicitWidth + 10
                    height: 20
                    radius: 10
                    color: Qt.alpha(Theme.surface, 0.75)

                    Row {
                        id: kindRow
                        anchors.centerIn: parent
                        spacing: 2

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData.kind === "scene" ? "auto_awesome" : "play_arrow"
                            font.pixelSize: 13
                            animateChange: false
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData.kind === "scene" ? "Escena" : "Video"
                            font.pixelSize: Theme.font.small - 1
                        }
                    }
                }

                StateLayer {
                    id: touch
                    radius: Theme.radius.normal
                    onClicked: {
                        grid.currentIndex = cell.index;
                        root.activate(cell.index);
                    }
                }

                // Borde: el fondo puesto (acento) o la selección con teclado.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: Theme.radius.normal + 2
                    color: "transparent"
                    border.width: 2
                    border.color: cell.current ? Theme.primary : Qt.alpha(Theme.text, 0.6)
                    visible: cell.current || cell.selected
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
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
    }

    // ── Transición (solo si Elaren dibuja el fondo) ──────────────────────
    Row {
        id: transitionsRow

        y: grid.visible ? grid.y + grid.height + Theme.spacing.small : empty.y + empty.height + Theme.spacing.normal
        height: 28
        spacing: Theme.spacing.small
        visible: Wallpaper.drawsOwn

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Transición"
            color: Theme.textMuted
            font.pixelSize: Theme.font.small
            rightPadding: Theme.spacing.small
        }

        Repeater {
            model: [
                { id: "fade", label: "Fundido", icon: "gradient" },
                { id: "zoom", label: "Zoom", icon: "zoom_in" },
                { id: "slide", label: "Deslizar", icon: "swipe_left" },
                { id: "wipe", label: "Barrido", icon: "view_column" },
                { id: "circle", label: "Círculo", icon: "radio_button_unchecked" },
                { id: "random", label: "Al azar", icon: "shuffle" }
            ]

            Chip {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                selected: Config.wallpaperTransition === modelData.id
                onClicked: Config.wallpaperTransition = modelData.id
            }
        }
    }

    // ── Biblioteca vacía o carpeta inexistente ───────────────────────────
    Column {
        id: empty

        y: header.height + Theme.spacing.normal + 20
        width: parent.width
        spacing: Theme.spacing.normal
        visible: root.items.length === 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Wallpaper.browsing ? "hourglass_empty" : "hide_image"
            color: Theme.textMuted
            font.pixelSize: 32
            animateChange: false
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Wallpaper.browsing ? "Buscando fondos…" : "No hay fondos en esta carpeta"
            color: Theme.textMuted
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Wallpaper.browsing && Wallpaper.atRoot
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
