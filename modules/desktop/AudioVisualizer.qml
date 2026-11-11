pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Visualizador de escritorio: barras estilo cava u ondas sobre el fondo de
// pantalla, debajo de las ventanas, mientras suena música.
//
// - Va en cualquier lugar de la pantalla y en cualquier dirección (las barras
//   crecen hacia arriba, abajo, izquierda o derecha): Config.visualizerX/Y,
//   visualizerLength y visualizerDirection.
// - Modo "acomodar" (Visualizer.placing): se arrastra con el ratón (con imán
//   a bordes y centro), la rueda cambia el largo y el clic derecho lo gira.
//   Esc o "Listo" termina. Entrada: Configuración → Visualizador → Mover, o
//   qs ipc -p <ruta>/shell.qml call visualizer place
// - Fuera de ese modo es una ventana del tamaño justo en la capa "Bottom",
//   que no recibe clics: el escritorio sigue usable.
// - Toma el color de la portada del tema que suena.
// - Aparece al reproducir y se desvanece al pausar; sin música no trabaja.
PanelWindow {
    id: root

    readonly property int maxHeight: Config.visualizerHeight
    readonly property color accent: Config.visualizerColor === "cover" ? Media.accent : Theme.primary
    readonly property string style: Visualizer.style
    readonly property bool placing: Visualizer.placing

    // ── Geometría ─────────────────────────────────────────────────────────
    readonly property real screenW: screen?.width ?? 1920
    readonly property real screenH: screen?.height ?? 1080
    readonly property string direction: ["up", "down", "left", "right"].includes(Config.visualizerDirection)
        ? Config.visualizerDirection : "up"
    readonly property bool horizontal: direction === "up" || direction === "down"
    readonly property real lengthFraction: Math.max(0.1, Math.min(1, Config.visualizerLength))
    // Profundidad: espacio hacia donde crecen las barras
    readonly property int depth: maxHeight + 24
    readonly property int stageW: horizontal ? Math.round(lengthFraction * screenW) : depth
    readonly property int stageH: horizontal ? depth : Math.round(lengthFraction * screenH)
    readonly property int stageX: Math.round(Math.max(0, Math.min(1, Config.visualizerX)) * Math.max(0, screenW - stageW))
    readonly property int stageY: Math.round(Math.max(0, Math.min(1, Config.visualizerY)) * Math.max(0, screenH - stageH))

    // Ángulo acumulado (gira siempre por el camino corto, sin dar la vuelta)
    readonly property real baseAngle: ({ up: 0, right: 90, down: 180, left: 270 })[direction]
    property real angle: baseAngle
    onBaseAngleChanged: {
        let a = baseAngle;
        while (a - angle > 180) a -= 360;
        while (a - angle < -180) a += 360;
        angle = a;
    }

    // Acomodando: pantalla completa por encima de las ventanas (para poder
    // arrastrarlo a cualquier lado). Si no: ventana del tamaño del espectro,
    // ubicada con márgenes, debajo de las ventanas.
    anchors {
        top: true
        left: true
        bottom: placing
        right: placing
    }
    margins {
        left: placing ? 0 : stageX
        top: placing ? 0 : stageY
    }
    implicitWidth: placing ? screenW : stageW
    implicitHeight: placing ? screenH : stageH
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: placing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "elaren-visualizer"
    WlrLayershell.keyboardFocus: placing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Región de entrada vacía: los clics pasan al escritorio (salvo acomodando).
    Region { id: noInput }
    mask: placing ? null : noInput

    // Aparece con la música; al pausar espera un poco antes de irse.
    property real amount: 0
    // Visible solo si suena algo de verdad: con el audio silenciado o en un
    // silencio largo se oculta (si no, quedaba una línea plana en pantalla).
    readonly property bool active: (Media.playing && audible) || placing
    property bool audible: true
    readonly property bool hearing: Visualizer.level > 0.02
    onHearingChanged: {
        if (hearing) {
            silence.stop();
            audible = true;
        } else {
            silence.restart();
        }
    }
    Timer {
        id: silence
        interval: 2500
        onTriggered: root.audible = false
    }
    onActiveChanged: {
        fade.duration = active ? 700 : 1600;
        amount = active ? 1 : 0;
    }
    Component.onCompleted: amount = active ? 1 : 0
    Behavior on amount { NumberAnimation { id: fade; easing.type: Easing.InOutQuad } }

    visible: amount > 0.001 || placing

    // ── Modo acomodar: fondo atenuado y guías ─────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.placing
        color: Qt.alpha("black", 0.35)

        Anim on opacity { running: root.placing; from: 0; to: 1; duration: Theme.anim.normal }
    }

    // Guías de imán (centro y bordes de la pantalla)
    Rectangle {
        visible: root.placing && drag.snapX !== null
        x: Math.round(drag.snapX ?? 0)
        width: 1
        height: parent.height
        color: Theme.primary
        opacity: 0.85
    }
    Rectangle {
        visible: root.placing && drag.snapY !== null
        y: Math.round(drag.snapY ?? 0)
        width: parent.width
        height: 1
        color: Theme.primary
        opacity: 0.85
    }

    // ── El espectro ───────────────────────────────────────────────────────
    // El suavizado y las "tapitas" se calculan en el servicio: un
    // FrameAnimation dentro de esta ventana de fondo depende de que el
    // compositor le pida cuadros, y en la capa "Bottom" casi no lo hace.
    Item {
        id: stage

        x: !root.placing ? 0 : drag.dragging ? drag.dragX : root.stageX
        y: !root.placing ? 0 : drag.dragging ? drag.dragY : root.stageY
        width: root.stageW
        height: root.stageH

        // Al acomodar, los cambios de tamaño y de lugar se animan.
        Behavior on x { enabled: root.placing && !drag.dragging; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
        Behavior on y { enabled: root.placing && !drag.dragging; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
        Behavior on width { enabled: root.placing; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }
        Behavior on height { enabled: root.placing; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }

        // Marco mientras se acomoda
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            visible: root.placing
            radius: 18
            color: Qt.alpha(Theme.primary, drag.dragging ? 0.12 : 0.06)
            border.width: 2
            border.color: Qt.alpha(Theme.primary, drag.dragging || drag.containsMouse ? 0.95 : 0.6)

            Behavior on color { CAnim {} }
            Behavior on border.color { CAnim {} }

            // Flecha que indica hacia dónde crecen las barras
            Rectangle {
                anchors.centerIn: parent
                width: 44
                height: 44
                radius: 22
                color: Theme.primary
                rotation: root.angle

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "arrow_upward"
                    color: Theme.textOnPrimary
                    font.pixelSize: 24
                    animateChange: false
                }
            }
        }

        // Contenido "hacia arriba" del largo del espectro, girado según la
        // dirección. Gira sobre su centro, así cabe justo en el escenario.
        Item {
            id: content

            anchors.centerIn: parent
            width: root.horizontal ? parent.width : parent.height
            height: root.depth
            rotation: root.angle
            opacity: root.amount * Config.visualizerOpacity

            Behavior on rotation { enabled: root.placing; Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }

            // Resplandor de color al pie, que sube con el volumen
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 1.05
                height: root.maxHeight * (0.35 + Visualizer.level * 0.5)
                opacity: 0.35
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.alpha(root.accent, 0.45) }
                }
            }

            SpectrumView {
                anchors.fill: parent
                anchors.bottomMargin: 4
                values: Visualizer.display.map(v => v * root.amount)
                caps: Visualizer.caps.map(v => v * root.amount)
                style: root.style
                colorMode: Config.visualizerColor
                color: root.accent
                maxHeight: root.maxHeight
                barWidth: Config.visualizerBarWidth
                showCaps: Config.visualizerCaps
            }
        }

        // Arrastrar = mover · rueda = largo · clic derecho = girar
        MouseArea {
            id: drag

            property bool dragging: false
            property real grabX: 0
            property real grabY: 0
            property real dragX: 0
            property real dragY: 0
            property var snapX: null
            property var snapY: null

            anchors.fill: parent
            enabled: root.placing
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            // Busca un imán (borde o centro de la pantalla) para el
            // escenario en `pos` con tamaño `size`; devuelve la posición.
            function snap(pos: real, size: real, total: real, axis: string): real {
                const lines = [0, total / 2, total];
                let best = null;
                for (const offset of [0, size / 2, size]) {
                    for (const line of lines) {
                        const delta = line - (pos + offset);
                        if (Math.abs(delta) <= 14 && (!best || Math.abs(delta) < Math.abs(best.delta)))
                            best = { delta, line };
                    }
                }
                if (axis === "x") snapX = best ? best.line : null;
                else snapY = best ? best.line : null;
                return Math.max(0, Math.min(total - size, pos + (best ? best.delta : 0)));
            }

            onPressed: event => {
                if (event.button === Qt.RightButton) {
                    root.rotate(1);
                    return;
                }
                grabX = event.x;
                grabY = event.y;
                dragX = stage.x;
                dragY = stage.y;
                dragging = true;
            }
            onPositionChanged: event => {
                if (!dragging) return;
                const p = mapToItem(null, event.x, event.y);
                dragX = snap(p.x - grabX, stage.width, root.screenW, "x");
                dragY = snap(p.y - grabY, stage.height, root.screenH, "y");
            }
            onReleased: finish()
            onCanceled: finish()
            onWheel: event => {
                const step = event.angleDelta.y > 0 ? 0.04 : -0.04;
                Config.visualizerLength = Math.round(Math.max(0.15, Math.min(1, root.lengthFraction + step)) * 100) / 100;
            }

            function finish(): void {
                if (!dragging) return;
                const freeW = root.screenW - stage.width;
                const freeH = root.screenH - stage.height;
                Config.visualizerX = freeW > 0 ? dragX / freeW : 0.5;
                Config.visualizerY = freeH > 0 ? dragY / freeH : 0.5;
                dragging = false;
                snapX = null;
                snapY = null;
            }
        }
    }

    // Gira el visualizador 90° (1 = horario, -1 = antihorario).
    function rotate(step: int): void {
        const order = ["up", "right", "down", "left"];
        Config.visualizerDirection = order[(order.indexOf(direction) + step + 4) % 4];
    }

    // ── Barra de herramientas del modo acomodar ───────────────────────────
    component ToolButton: Rectangle {
        id: tool

        property string icon
        property string label
        property bool primary: false
        signal clicked()

        width: label ? toolRow.implicitWidth + 24 : 36
        height: 36
        radius: 18
        color: primary ? Theme.primary : Qt.alpha(Theme.text, 0.08)

        Row {
            id: toolRow
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: tool.icon
                font.pixelSize: 20
                color: tool.primary ? Theme.textOnPrimary : Theme.text
                animateChange: false
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: tool.label !== ""
                text: tool.label
                font.weight: Font.Bold
                color: tool.primary ? Theme.textOnPrimary : Theme.text
            }
        }

        StateLayer {
            radius: 18
            onClicked: tool.clicked()
        }
    }

    Rectangle {
        id: toolbar

        visible: root.placing
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.placing ? Theme.bar.height + 24 : -height
        width: tools.implicitWidth + 20
        height: 56
        radius: 28
        color: Qt.alpha(Theme.surface, 0.96)
        border.color: Theme.glassBorder
        border.width: 1

        Behavior on y { Anim { duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive } }

        Row {
            id: tools
            anchors.centerIn: parent
            spacing: 8

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                rightPadding: 6
                text: "Arrastrá para mover · rueda: largo · clic derecho: girar"
                color: Theme.textMuted
                font.pixelSize: Theme.font.small
            }

            ToolButton { anchors.verticalCenter: parent.verticalCenter; icon: "rotate_left"; onClicked: root.rotate(-1) }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; icon: "rotate_right"; onClicked: root.rotate(1) }
            ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "remove"
                onClicked: Config.visualizerLength = Math.max(0.15, Math.round((root.lengthFraction - 0.1) * 100) / 100)
            }
            ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "add"
                onClicked: Config.visualizerLength = Math.min(1, Math.round((root.lengthFraction + 0.1) * 100) / 100)
            }
            ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "check"
                label: "Listo"
                primary: true
                onClicked: Visualizer.placing = false
            }
        }
    }

    // Esc termina
    Item {
        focus: root.placing
        Keys.onEscapePressed: Visualizer.placing = false
        Keys.onReturnPressed: Visualizer.placing = false
    }
}
