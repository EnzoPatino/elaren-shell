import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Barra de escritorio compacta con isla central.
//
// La ventana no reserva espacio (de eso se encarga BarReserve), así la isla
// puede crecer desde la barra sin empujar ventanas. Con la isla cerrada la
// ventana es solo la franja del borde: una superficie a pantalla completa
// obligaría a Qt y a KWin a redibujar y componer 1920×1080 en cada tic del
// reloj. Al abrir la isla pasa a cubrir toda la pantalla (transparente) para
// que un clic afuera la cierre, y vuelve a la franja al terminar de cerrarse.
//
// Barra e isla se dibujan como UNA forma de vidrio. La geometría se calcula en
// un marco "canónico" (X a lo largo de la barra, Y hacia el interior de la
// pantalla) y una matriz la lleva al borde elegido. El contenido nunca se
// dibuja en ese marco: la barra conserva su rotación de siempre y la isla se
// muestra derecha.
PanelWindow {
    id: root

    readonly property string edge: Config.barPosition
    readonly property bool vertical: edge === "left" || edge === "right"

    // Abierta (o animando el cierre): pantalla completa. Cerrada: la franja.
    readonly property bool expanded: islandOpen || islandShown

    anchors {
        top: edge === "top" || vertical || expanded
        bottom: edge === "bottom" || vertical || expanded
        left: edge === "left" || !vertical || expanded
        right: edge === "right" || !vertical || expanded
    }
    implicitWidth: vertical ? thickness + 2 * inset : 0
    implicitHeight: vertical ? 0 : thickness + 2 * inset
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "elaren-bar"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Teclado solo con la isla abierta (para Escape).
    WlrLayershell.keyboardFocus: islandOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.islandShown ? catcher : barArea }

    // Desenfoque real (KWin) detrás de la barra y de la isla.
    BackgroundEffect.blurRegion: Region {
        item: barArea
        radius: root.barRadius

        Region { item: islandBox; radius: Theme.radius.large }
        Region { item: islandJoint }
    }

    property bool revealed: false

    // Cafeína: mientras está activa, la sesión no se suspende ni se bloquea.
    IdleInhibitor {
        window: root
        enabled: Caffeine.enabled
    }

    // ── Estado ────────────────────────────────────────────────────────────
    // Todo lo que antes eran popups o grupos de la barra (música, calendario,
    // recursos, bandeja) vive ahora en las pestañas de la isla: hay una sola superficie abierta a la vez.
    property bool islandOpen: false
    readonly property bool islandShown: openness > 0.001

    function toggleIsland(tab: string): void {
        if (islandOpen && island.tab === tab) {
            islandOpen = false;
            return;
        }
        island.tab = tab;
        islandOpen = true;
    }

    // Abre con rebote y cierra acelerando, como los popups.
    property real openness: 0
    onIslandOpenChanged: {
        opennessAnim.easing.bezierCurve = islandOpen ? Theme.anim.expressive : Theme.anim.emphasizedAccel;
        opennessAnim.duration = islandOpen ? Theme.anim.slow : Theme.anim.normal;
        openness = islandOpen ? 1 : 0;
        if (islandOpen) islandBox.forceActiveFocus();
    }
    Behavior on openness { Anim { id: opennessAnim } }

    // Durante una captura de pantalla la isla se cierra.
    Connections {
        target: KWin
        function onScreenshotActiveChanged(): void {
            if (KWin.screenshotActive) root.islandOpen = false;
        }
    }

    // Un tic de retardo para que los Behavior ya estén activos.
    Timer {
        interval: 60
        running: true
        onTriggered: root.revealed = true
    }

    // ── Geometría canónica ────────────────────────────────────────────────
    readonly property real lengthExtent: vertical ? height : width
    readonly property real thickness: vertical ? Theme.bar.height : Theme.bar.height + Theme.spacing.large - 2 * Theme.spacing.small
    readonly property real inset: vertical ? Theme.spacing.large : Theme.spacing.small
    readonly property real barRadius: Math.min(Theme.radius.large, thickness / 2)

    // Entrada al arrancar: la barra llega desde afuera de la pantalla.
    property real slide: revealed ? 0 : 1
    Behavior on slide { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.expressive } }

    readonly property real contentLength: mainRow.implicitWidth + 2 * (Theme.spacing.small + 1)

    // Tamaño natural de la isla en el marco canónico (suavizado al cambiar
    // de pestaña).
    property real islandAlong: vertical ? island.implicitHeight : island.implicitWidth
    property real islandAcross: vertical ? island.implicitWidth : island.implicitHeight
    Behavior on islandAlong { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel } }
    Behavior on islandAcross { Anim { duration: Theme.anim.normal; easing.bezierCurve: Theme.anim.emphasizedDecel } }

    readonly property real p: Math.max(0, openness)
    readonly property real islandW: clock.width + (islandAlong - clock.width) * Math.min(1, p)
    readonly property real islandH: islandAcross * p
    readonly property real filletRadius: Math.min(Theme.radius.normal, islandH / 2)

    readonly property real barTop: inset - slide * (thickness + inset + 4)
    readonly property real barBottom: barTop + thickness

    // El avatar con el reloj queda justo en el medio de la pantalla y la
    // barra se extiende hacia cada lado lo que ocupe su contenido (sin
    // relleno: si un lado tiene menos cosas, la barra es más corta de ese
    // lado). A la izquierda la composición está girada -90°, así que el
    // orden va de abajo hacia arriba.
    // Configuración → Barra elige qué queda en el medio: la barra entera
    // ("center") o el avatar con el reloj ("clock").
    readonly property bool clockCentered: Config.barAlignment === "clock"
    readonly property real clockOffset: mainRow.x + clock.x + clock.width / 2
    readonly property real contentStart: !clockCentered ? (lengthExtent - contentLength) / 2
        : edge === "left" ? lengthExtent / 2 - contentLength + clockOffset
        : lengthExtent / 2 - clockOffset
    readonly property real clockCenter: edge === "left" ? contentStart + contentLength - clockOffset : contentStart + clockOffset

    // La isla nace del reloj, sin salirse de la pantalla.
    readonly property real islandMargin: barRadius + filletRadius + Theme.spacing.large
    readonly property real islandStart: Math.max(islandMargin, Math.min(clockCenter - islandW / 2, lengthExtent - islandMargin - islandW))

    // Si la isla abierta es más ancha que la barra, la barra se estira para
    // abrazarla (con lugar para las curvas de la unión).
    readonly property real barStart: Math.max(Theme.spacing.large, Math.min(contentStart, islandShown ? islandStart - islandMargin + Theme.spacing.large : contentStart))
    readonly property real barLength: Math.min(lengthExtent - Theme.spacing.large,
        Math.max(contentStart + contentLength, islandShown ? islandStart + islandW + islandMargin - Theme.spacing.large : 0)) - barStart

    // Rectángulo canónico → pantalla.
    function toScreen(x0: real, y0: real, x1: real, y1: real): rect {
        switch (edge) {
        case "bottom": return Qt.rect(x0, height - y1, x1 - x0, y1 - y0);
        case "left": return Qt.rect(y0, x0, y1 - y0, x1 - x0);
        case "right": return Qt.rect(width - y1, x0, y1 - y0, x1 - x0);
        default: return Qt.rect(x0, y0, x1 - x0, y1 - y0);
        }
    }

    readonly property rect barRect: toScreen(barStart, barTop, barStart + barLength, barBottom)
    readonly property rect islandRect: toScreen(islandStart, barBottom, islandStart + islandW, barBottom + islandH)
    readonly property rect jointRect: toScreen(islandStart, barBottom - 1, islandStart + islandW, barBottom + Math.min(islandH, Theme.radius.large))

    // Contorno de barra + isla con empalmes cóncavos donde se unen.
    readonly property string outline: {
        const r = barRadius;
        const x0 = barStart, x1 = barStart + barLength, y0 = barTop, y1 = barBottom;
        const top = `M ${x0 + r} ${y0} H ${x1 - r} A ${r} ${r} 0 0 1 ${x1} ${y0 + r} V ${y1 - r} A ${r} ${r} 0 0 1 ${x1 - r} ${y1}`;
        const close = `H ${x0 + r} A ${r} ${r} 0 0 1 ${x0} ${y1 - r} V ${y0 + r} A ${r} ${r} 0 0 1 ${x0 + r} ${y0} Z`;
        if (islandH < 1) return top + " " + close;

        const f = filletRadius;
        const R = Math.min(Theme.radius.large, islandH / 2, islandW / 2);
        const ix0 = islandStart, ix1 = islandStart + islandW, iy1 = y1 + islandH;
        const island = `H ${ix1 + f} A ${f} ${f} 0 0 0 ${ix1} ${y1 + f} V ${iy1 - R} A ${R} ${R} 0 0 1 ${ix1 - R} ${iy1}`
            + ` H ${ix0 + R} A ${R} ${R} 0 0 1 ${ix0} ${iy1 - R} V ${y1 + f} A ${f} ${f} 0 0 0 ${ix0 - f} ${y1}`;
        return top + " " + island + " " + close;
    }

    // ── Clic afuera ───────────────────────────────────────────────────────
    MouseArea {
        id: catcher
        anchors.fill: parent
        enabled: root.islandOpen
        acceptedButtons: Qt.AllButtons
        onPressed: root.islandOpen = false
    }

    // El avatar sigue al cursor mientras está sobre la barra o la isla.
    HoverHandler { id: pointer }

    readonly property point avatarLook: {
        if (!Config.barAvatarFollow || !pointer.hovered) return Qt.point(0, 0);
        const c = toScreen(clockCenter, barTop, clockCenter, barBottom);
        const dx = Math.max(-1, Math.min(1, (pointer.point.position.x - (c.x + c.width / 2)) / 160));
        const dy = Math.max(-1, Math.min(1, (pointer.point.position.y - (c.y + c.height / 2)) / 160));
        return Qt.point(dx, dy);
    }
    // En la barra girada, el avatar mira en sus propias coordenadas.
    readonly property point barLook: edge === "left" ? Qt.point(-avatarLook.y, avatarLook.x)
        : edge === "right" ? Qt.point(avatarLook.y, -avatarLook.x) : avatarLook

    // ── Vidrio ────────────────────────────────────────────────────────────
    Item {
        id: canon

        width: root.lengthExtent
        height: root.vertical ? root.width : root.height
        transform: Matrix4x4 {
            matrix: root.edge === "bottom" ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, root.height, 0, 0, 1, 0, 0, 0, 0, 1)
                : root.edge === "left" ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : root.edge === "right" ? Qt.matrix4x4(0, -1, 0, root.width, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : Qt.matrix4x4()
        }

        Shape {
            anchors.fill: parent
            // Sin `asynchronous`: la forma cambia en cada cuadro de la animación.
            preferredRendererType: Shape.CurveRenderer
            opacity: root.revealed ? 1 : 0
            Behavior on opacity { Anim { duration: Theme.anim.slow } }

            ShapePath {
                fillColor: Theme.glass
                strokeColor: Theme.glassBorder
                strokeWidth: 1
                PathSvg { path: root.outline }
            }
        }
    }

    // ── Barra ─────────────────────────────────────────────────────────────
    Item {
        id: barArea

        x: root.barRect.x
        y: root.barRect.y
        width: root.barRect.width
        height: root.barRect.height
        opacity: root.revealed ? 1 : 0
        Behavior on opacity { Anim { duration: Theme.anim.slow } }

        // Brillo y tono de la música: solo sobre la barra, se apagan al
        // abrir la isla para que no se note la unión.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.barRadius - 1
            opacity: 1 - Math.min(1, root.p)
            gradient: Gradient {
                GradientStop { position: 0.4; color: "transparent" }
                GradientStop { position: 1; color: Theme.glassHighlight }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.barRadius - 1
            opacity: Media.available ? 1 - Math.min(1, root.p) : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(Media.accent, 0.19) }
                GradientStop { position: 0.48; color: Qt.alpha(Media.accent, 0.035) }
                GradientStop { position: 1; color: Qt.alpha(Theme.secondary, 0.12) }
            }
            Behavior on opacity { Anim { duration: Theme.anim.slow } }
        }

        // En los laterales se gira la composición completa para conservar el
        // orden y el tamaño de los controles de la barra horizontal.
        Item {
            id: content

            // Centro del contenido medido desde el comienzo de la barra.
            readonly property real along: root.contentStart + root.contentLength / 2 - root.barStart

            x: (root.vertical ? parent.width / 2 : along) - width / 2
            y: (root.vertical ? along : parent.height / 2) - height / 2
            width: root.contentLength
            height: root.thickness
            rotation: root.edge === "left" ? -90 : root.edge === "right" ? 90 : 0

            Row {
                id: mainRow

                x: Theme.spacing.small + 1
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.large

                // ── Izquierda ─────────────────────────────────────────────
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.normal

                    LauncherButton {
                        anchors.verticalCenter: parent.verticalCenter
                        revealed: root.revealed
                    }

                    Reveal {
                        anchors.verticalCenter: parent.verticalCenter
                        shown: Workspaces.list.length > 0 && Config.barShowWorkspaces

                        BarGroup {
                            padding: 3
                            revealed: root.revealed
                            revealDelay: 120

                            WorkspacesWidget {
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    ActiveWindow {
                        anchors.verticalCenter: parent.verticalCenter
                        revealed: root.revealed && Config.barShowActiveWindow
                        revealDelay: 160
                        maxWidth: Math.min(260, root.lengthExtent * 0.14)
                    }
                }

                // ── Centro: avatar + reloj ────────────────────────────────
                Clock {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    revealed: root.revealed
                    revealDelay: 200
                    open: root.islandOpen
                    lookX: root.barLook.x
                    lookY: root.barLook.y
                    onClicked: root.islandOpen ? root.islandOpen = false : root.toggleIsland(Config.barIslandRemember ? island.tab : "home")
                }

                // ── Derecha ───────────────────────────────────────────────
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.normal

                    // Modo gaming: en beta, visible pero deshabilitado.
                    GameModeButton {
                        anchors.verticalCenter: parent.verticalCenter
                        revealed: root.revealed
                        revealDelay: 340
                    }

                    BarGroup {
                        revealed: root.revealed
                        revealDelay: 380

                        CaffeineButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.barShowCaffeine
                        }

                        NetworkWidget {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.barShowNetwork
                        }

                        BrightnessWidget {
                            anchors.verticalCenter: parent.verticalCenter
                            shown: Brightness.available && Config.barShowBrightness
                        }

                        VolumeWidget {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.barShowVolume
                        }

                        BatteryWidget {
                            anchors.verticalCenter: parent.verticalCenter
                            shown: Battery.available && Config.barShowBattery
                        }
                    }
                }
            }
        }
    }

    // ── Isla ──────────────────────────────────────────────────────────────
    // Franja de la unión con la barra, solo para el desenfoque.
    Item {
        id: islandJoint
        x: root.jointRect.x
        y: root.jointRect.y
        width: root.islandShown ? root.jointRect.width : 0
        height: root.islandShown ? root.jointRect.height : 0
    }

    Item {
        id: islandBox

        x: root.islandRect.x
        y: root.islandRect.y
        width: root.islandRect.width
        height: root.islandRect.height
        visible: root.islandShown
        clip: true
        focus: root.islandOpen

        Keys.onEscapePressed: root.islandOpen = false

        // Los clics dentro de la isla no llegan al "clic afuera".
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Island {
            id: island

            width: implicitWidth
            height: implicitHeight
            // Pegada al lado de la barra, centrada en el otro eje.
            x: root.edge === "left" ? 0 : root.edge === "right" ? parent.width - width : (parent.width - width) / 2
            y: root.edge === "top" ? 0 : root.edge === "bottom" ? parent.height - height : (parent.height - height) / 2
            opacity: Math.min(1, root.p * root.p)
            active: root.islandShown
            barWindow: root
            lookX: root.avatarLook.x
            lookY: root.avatarLook.y
            onCloseRequested: root.islandOpen = false
        }
    }
}
