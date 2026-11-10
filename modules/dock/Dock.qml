pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Dock inferior. El icono bajo el cursor se eleva y crece un poco (sus
// vecinos, menos), pero cada icono ocupa siempre el mismo hueco: el dock no
// cambia de ancho ni se recentra al mover el ratón, así que nada "salta".
//
// - Apps fijadas (Config.pinnedApps) + apps abiertas, separadas por una línea.
// - Clic: abre la app, o alterna/rota entre sus ventanas. Medio: nueva instancia.
// - Se esconde solo y aparece al tocar el borde inferior (o si el escritorio
//   actual no tiene ventanas).
PanelWindow {
    id: dock

    readonly property int iconSize: Config.dockIconSize
    readonly property int padding: 8
    readonly property int spacing: 8
    readonly property int bottomGap: 8
    readonly property int tooltipSpace: 40

    readonly property int separatorWidth: 13
    readonly property int indicatorSpace: 4 // aire extra bajo los iconos para los puntos

    // Realce al pasar el ratón: escala del icono bajo el cursor, de sus
    // vecinos inmediatos y cuánto sube. Los valores dejan aire suficiente
    // con `spacing` para que dos iconos ampliados nunca se toquen.
    readonly property real hoverScale: Config.dockMagnification ? 1.22 : 1.04
    readonly property real neighbourScale: Config.dockMagnification ? 1.07 : 1
    readonly property int lift: 7
    readonly property real headroom: iconSize * (hoverScale - 1) + lift

    // Centro de cada hueco respecto del centro del dock. Como el layout es
    // fijo, coincide siempre con la posición real de los iconos.
    readonly property list<real> baseCenters: {
        const widths = Apps.dockIds.map(id => id === Apps.separator ? separatorWidth : iconSize);
        const total = widths.reduce((a, b) => a + b, 0) + spacing * Math.max(0, widths.length - 1);
        const centers = [];
        let x = -total / 2;
        for (const w of widths) {
            centers.push(x + w / 2);
            x += w + spacing;
        }
        return centers;
    }
    readonly property real baseWidth: baseCenters.length > 0
        ? baseCenters[baseCenters.length - 1] - baseCenters[0] + iconSize
        : 0

    // Ratón relativo al centro del dock.
    property real pointerX: 0
    readonly property bool hovering: zoneHover.hovered

    // Icono bajo el ratón (-1 = ninguno). El área de cada icono llega hasta
    // la mitad del hueco con el vecino, así no hay "zonas muertas" entre
    // iconos que hagan parpadear el realce o la etiqueta.
    readonly property int hoveredIndex: {
        if (!hovering) return -1;
        let best = -1;
        let bestDistance = (iconSize + spacing) / 2 + 1;
        for (let i = 0; i < baseCenters.length; i++) {
            const d = Math.abs(baseCenters[i] - pointerX);
            if (d < bestDistance && Apps.dockIds[i] !== Apps.separator) {
                best = i;
                bestDistance = d;
            }
        }
        return best;
    }

    // 0 = sin realce, 1 = vecino, 2 = bajo el cursor. Es discreto a propósito:
    // la transición la suaviza una animación, no el movimiento del ratón.
    function emphasis(index: int): int {
        if (hoveredIndex < 0 || Apps.dockIds[index] === Apps.separator) return 0;
        if (index === hoveredIndex) return 2;
        // Vecinos saltando el separador
        let left = hoveredIndex - 1, right = hoveredIndex + 1;
        if (Apps.dockIds[left] === Apps.separator) left--;
        if (Apps.dockIds[right] === Apps.separator) right++;
        return index === left || index === right ? 1 : 0;
    }

    property bool peeking: true
    property bool lingering: false
    readonly property bool desktopEmpty: KWin.connected
        && KWin.windowsOn(KWin.currentDesktop).every(w => w.minimized)
    readonly property bool shown: !Config.dockAutoHide || hovering || lingering || peeking || desktopEmpty

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: tooltipSpace + headroom + iconSize + padding * 2 + indicatorSpace + bottomGap
    color: "transparent"
    exclusionMode: Config.dockAutoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: Config.dockAutoHide ? 0 : iconSize + padding * 2 + indicatorSpace + bottomGap
    WlrLayershell.namespace: "elaren-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Solo la zona del dock (o una franja en el borde si está oculto) recibe
    // eventos; el resto de la ventana deja pasar los clics.
    mask: Region { item: dock.shown ? zone : trigger }

    // Al arrancar se muestra un momento para que se sepa que existe.
    Timer {
        interval: 2500
        running: true
        onTriggered: dock.peeking = false
    }

    Timer {
        id: lingerTimer
        interval: 600
        onTriggered: dock.lingering = false
    }

    property real slide: 0
    function updateSlide(): void {
        slideAnim.easing.bezierCurve = shown ? Theme.anim.expressive : Theme.anim.emphasizedAccel;
        slideAnim.duration = shown ? Theme.anim.extraSlow : Theme.anim.normal;
        slide = shown ? 1 : 0;
    }
    onShownChanged: updateSlide()
    Component.onCompleted: updateSlide()
    Behavior on slide { Anim { id: slideAnim } }

    Item {
        id: content
        anchors.fill: parent

        // Franja sensible en el borde inferior cuando el dock está oculto.
        Item {
            id: trigger
            anchors.bottom: parent.bottom
            width: parent.width
            height: 3

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        dock.lingering = true;
                        lingerTimer.restart();
                    }
                }
            }
        }

        // Zona interactiva fija (no depende del realce ni de la animación de
        // entrada): el dock más el espacio que ocupan los iconos elevados.
        Item {
            id: zone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: dock.baseWidth + dock.padding * 2
            height: dock.headroom + dock.iconSize + dock.padding * 2 + dock.indicatorSpace + dock.bottomGap

            HoverHandler {
                id: zoneHover
                onPointChanged: dock.pointerX = point.position.x - zone.width / 2
                onHoveredChanged: {
                    if (hovered) {
                        dock.lingering = true;
                        lingerTimer.stop();
                    } else {
                        lingerTimer.restart();
                    }
                }
            }
        }

        StyledRect {
            id: background

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - dock.bottomGap - height + (1 - dock.slide) * (height + dock.bottomGap + 12)
            width: row.width + dock.padding * 2
            height: dock.iconSize + dock.padding * 2 + dock.indicatorSpace
            radius: Theme.radius.large + 4
            color: Qt.alpha(Theme.surface, 0.94)
            border.color: Qt.alpha(Theme.outline, 0.7)
            border.width: 1
            opacity: Math.min(1, dock.slide * 1.5)

            // Halo suave que sigue al icono bajo el cursor
            Rectangle {
                id: halo

                readonly property Item target: dock.hoveredIndex >= 0 ? repeater.itemAt(dock.hoveredIndex) : null
                property real restingX: 0

                x: target ? row.x + target.x + target.width / 2 - width / 2 : restingX
                onXChanged: if (target) restingX = x
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: dock.iconSize + 12
                height: dock.iconSize * 0.9
                radius: Theme.radius.large
                color: Qt.alpha(Theme.primary, 0.10)
                opacity: target ? 1 : 0

                Behavior on x { enabled: halo.opacity > 0.05; Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                Behavior on opacity { Anim { duration: Theme.anim.normal } }
            }

            Row {
                id: row
                x: dock.padding
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dock.padding + dock.indicatorSpace
                spacing: dock.spacing

                Repeater {
                    id: repeater
                    model: ScriptModel { values: [...Apps.dockIds] }

                    Item {
                        id: item

                        required property string modelData
                        required property int index

                        readonly property bool isSeparator: modelData === Apps.separator
                        readonly property list<var> windows: isSeparator ? [] : Apps.windowsFor(modelData)
                        readonly property bool running: windows.length > 0
                        readonly property bool focused: windows.some(w => w.id === KWin.activeWindow)

                        readonly property int level: dock.emphasis(index)
                        readonly property real hoverScale: level === 2 ? dock.hoverScale : level === 1 ? dock.neighbourScale : 1
                        readonly property real hoverLift: level === 2 ? dock.lift : level === 1 ? dock.lift * 0.3 : 0
                        // 0 → 1 durante la entrada escalonada (no pisa el scale del hover)
                        property real appear: 0

                        width: isSeparator ? dock.separatorWidth : dock.iconSize
                        height: dock.iconSize

                        // Separador entre fijadas y abiertas
                        Rectangle {
                            visible: item.isSeparator
                            anchors.centerIn: parent
                            width: 1
                            height: dock.iconSize * 0.6
                            color: Theme.outline
                        }

                        Image {
                            id: icon

                            property real hoverScale: item.hoverScale
                            property real hoverLift: item.hoverLift

                            visible: !item.isSeparator
                            anchors.fill: parent
                            source: item.isSeparator ? "" : Apps.icon(item.modelData)
                            sourceSize: Qt.size(dock.iconSize * 2, dock.iconSize * 2)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            transformOrigin: Item.Bottom
                            scale: item.appear * hoverScale * (touch.pressed ? 0.88 : 1)

                            transform: [
                                Translate { y: -icon.hoverLift },
                                Translate { id: bounce }
                            ]

                            Behavior on hoverScale { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast } }
                            Behavior on hoverLift { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.expressiveFast } }
                        }

                        // Entrada escalonada
                        SequentialAnimation {
                            running: true
                            PropertyAction { target: item; property: "opacity"; value: 0 }
                            PropertyAction { target: item; property: "appear"; value: 0.3 }
                            PauseAnimation { duration: (150 + item.index * 45) * Theme.anim.scale }
                            ParallelAnimation {
                                Anim { target: item; property: "opacity"; to: 1 }
                                Anim { target: item; property: "appear"; to: 1; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast }
                            }
                        }

                        // Rebote mientras se abre la app
                        SequentialAnimation {
                            id: bounceAnim
                            loops: 3
                            Anim { target: bounce; property: "y"; to: -dock.iconSize * 0.35; duration: 260; easing.bezierCurve: Theme.anim.emphasizedDecel }
                            Anim { target: bounce; property: "y"; to: 0; duration: 260; easing.bezierCurve: Theme.anim.emphasizedAccel }
                        }

                        onRunningChanged: if (running && bounceAnim.running) bounceAnim.loops = 1

                        function bounceIcon(): void {
                            if (Theme.anim.scale <= 0) return;
                            bounceAnim.loops = 3;
                            bounceAnim.restart();
                        }

                        // Indicadores de ventanas abiertas
                        Row {
                            visible: !item.isSeparator
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height + 4
                            spacing: 3

                            Repeater {
                                model: Math.min(3, item.windows.length)

                                Rectangle {
                                    required property int index
                                    width: item.focused && index === 0 ? 14 : 4
                                    height: 4
                                    radius: 2
                                    color: item.focused ? Theme.primary : Theme.textMuted

                                    Anim on scale { from: 0; to: 1; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressiveFast }
                                    Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                                    Behavior on color { CAnim {} }
                                }
                            }
                        }

                        MouseArea {
                            id: touch

                            enabled: !item.isSeparator
                            anchors.fill: parent
                            anchors.topMargin: -dock.headroom
                            anchors.leftMargin: -dock.spacing / 2
                            anchors.rightMargin: -dock.spacing / 2
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: event => {
                                if (event.button === Qt.MiddleButton) {
                                    Apps.launch(item.modelData);
                                    item.bounceIcon();
                                } else if (Apps.activate(item.modelData)) {
                                    item.bounceIcon();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Etiqueta con el nombre de la app bajo el ratón
        Rectangle {
            id: tooltip

            readonly property var target: dock.hoveredIndex >= 0 ? repeater.itemAt(dock.hoveredIndex) : null
            readonly property string current: target
                ? Apps.name(target.modelData) + (target.windows.length > 1 ? `  ·  ${target.windows.length}` : "")
                : ""
            // Conserva el último texto y posición mientras se desvanece.
            property string text: ""
            property real restingX: 0
            onCurrentChanged: if (current) text = current
            onXChanged: if (target) restingX = x

            x: target
                ? background.x + row.x + target.x + target.width / 2 - width / 2
                : restingX
            // Justo encima del icono elevado
            y: background.y + dock.padding - dock.headroom - height - 8
            width: label.implicitWidth + 20
            height: 26
            radius: Theme.radius.full
            color: Theme.surfaceHigh
            border.color: Theme.outline
            border.width: 1
            opacity: target && dock.hovering && dock.slide > 0.9 ? 1 : 0
            scale: opacity > 0.5 ? 1 : 0.85
            transform: Translate { y: tooltip.opacity > 0.5 ? 0 : 4; Behavior on y { Anim { duration: Theme.anim.fast } } }

            Behavior on x { enabled: tooltip.opacity > 0; Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.emphasizedDecel } }
            Behavior on opacity { Anim { duration: Theme.anim.fast } }
            Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }

            StyledText {
                id: label
                anchors.centerIn: parent
                font.pixelSize: Theme.font.small
                font.weight: Font.Medium
                animate: true
                text: tooltip.text
            }
        }
    }
}
