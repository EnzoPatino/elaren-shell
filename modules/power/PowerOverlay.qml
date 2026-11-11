pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// Animaciones a pantalla completa de services/Power.qml, una por pantalla.
//
//   lock      el candado se cierra mientras la pantalla se oscurece
//   suspend   luna que se mece y fundido lento a negro
//   logout    saludo con la mano y un iris que se cierra
//   reboot    flecha que gira y un iris que se cierra
//   poweroff  apagado de televisor de tubo: la imagen se aplasta en una
//             línea, la línea en un punto y el punto se apaga
//   (desbloqueo) el iris se abre desde negro con un "Hola de nuevo"
//
// Mientras la acción no se ejecutó, Esc o un clic la cancelan.
PanelWindow {
    id: root

    readonly property string user: {
        const name = Quickshell.env("USER") ?? "";
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    readonly property real diag: Math.sqrt(width * width + height * height)
    readonly property bool wanted: Power.busy || Power.welcome || Power.locked

    // Escena que se dibuja; se conserva mientras la ventana se desvanece.
    property string scene: ""
    // Progreso de la animación previa (0..1)
    property real p: 0
    // Progreso de la bienvenida (0..1)
    property real w: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "elaren-power"
    WlrLayershell.keyboardFocus: Power.busy && !Power.committed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Durante la bienvenida los clics ya pasan al escritorio.
    Region { id: noInput }
    mask: Power.welcome && !Power.busy ? noInput : null

    visible: stageOpacity > 0.001
    property real stageOpacity: wanted ? 1 : 0
    Behavior on stageOpacity { Anim { duration: Theme.anim.slow } }

    function ease(x: real): real { return 1 - Math.pow(1 - Math.max(0, Math.min(1, x)), 3); }
    function easeIn(x: real): real { const c = Math.max(0, Math.min(1, x)); return c * c * c; }
    // Fracción de `x` dentro del tramo [a, b]
    function span(x: real, a: real, b: real): real { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    Connections {
        target: Power
        function onActionChanged(): void {
            if (Power.action === "") return;
            root.scene = Power.action;
            pAnim.duration = Math.max(1, Power.durations[Power.action] * Math.min(1, Theme.anim.scale));
            pAnim.restart();
        }
        function onWelcomeChanged(): void {
            if (!Power.welcome) return;
            root.scene = "welcome";
            root.w = 0;
            wAnim.restart();
        }
        function onLockedChanged(): void {
            // Bloqueo desde otro lado (Meta+L, inactividad): telón negro
            // debajo del bloqueador, listo para la bienvenida.
            if (Power.locked && !Power.busy) {
                root.scene = "locked";
                root.p = 1;
            }
        }
    }
    Component.onCompleted: if (Power.locked) { scene = "locked"; p = 1; }

    NumberAnimation { id: pAnim; target: root; property: "p"; from: 0; to: 1 }
    NumberAnimation { id: wAnim; target: root; property: "w"; from: 0; to: 1; duration: 2200 * Math.max(0.3, Theme.anim.scale) }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.stageOpacity

        // ── Velo que oscurece (lock, suspend, locked) ─────────────────────
        Rectangle {
            anchors.fill: parent
            visible: ["lock", "suspend", "locked"].includes(root.scene)
            color: "black"
            opacity: root.scene === "locked" ? 1
                : root.scene === "suspend" ? root.easeIn(root.p) * 0.6 + root.ease(root.span(root.p, 0.55, 1)) * 0.4
                : root.ease(root.p) * 0.75 + root.span(root.p, 0.8, 1) * 0.25
        }

        // ── Iris (logout, reboot y la bienvenida al revés) ───────────────
        // Un anillo negro enorme cuyo agujero se achica (o crece).
        Rectangle {
            readonly property real hole: root.scene === "welcome"
                ? root.diag * root.ease(root.span(root.w, 0.25, 0.8))
                : root.diag * (1 - root.ease(root.span(root.p, 0.15, 1)))

            visible: ["logout", "reboot", "welcome"].includes(root.scene)
            anchors.centerIn: parent
            width: hole + root.diag * 2
            height: width
            radius: width / 2
            color: "transparent"
            border.width: root.diag + 1
            border.color: "black"
        }

        // Borde de luz del iris
        Rectangle {
            readonly property real hole: root.scene === "welcome"
                ? root.diag * root.ease(root.span(root.w, 0.25, 0.8))
                : root.diag * (1 - root.ease(root.span(root.p, 0.15, 1)))

            visible: ["logout", "reboot", "welcome"].includes(root.scene) && hole > 4 && hole < root.diag * 0.98
            anchors.centerIn: parent
            width: hole
            height: hole
            radius: hole / 2
            color: "transparent"
            border.width: 3
            border.color: Qt.alpha(Theme.primary, 0.8)
        }

        // ── Apagado de tubo (poweroff) ────────────────────────────────────
        Item {
            id: crt

            anchors.fill: parent
            visible: root.scene === "poweroff"

            // 1) La imagen se aplasta: dos cortinas negras se juntan al medio
            readonly property real squash: root.easeIn(root.span(root.p, 0.3, 0.62))
            // 2) La línea se encoge a un punto
            readonly property real shrink: root.ease(root.span(root.p, 0.62, 0.82))
            // 3) El punto se apaga
            readonly property real fade: root.span(root.p, 0.82, 1)

            // Leve fundido previo
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.span(root.p, 0, 0.3) * 0.35
            }
            Rectangle {
                width: parent.width
                height: parent.height / 2 * crt.squash + (crt.squash >= 1 ? 1 : 0)
                color: "black"
            }
            Rectangle {
                y: parent.height - height
                width: parent.width
                height: parent.height / 2 * crt.squash + (crt.squash >= 1 ? 1 : 0)
                color: "black"
            }

            // Línea / punto de luz
            Rectangle {
                anchors.centerIn: parent
                visible: crt.squash > 0.9
                width: Math.max(6, parent.width * (1 - crt.shrink))
                height: crt.shrink < 1 ? 3 : 6
                radius: height / 2
                color: Qt.lighter(Theme.primary, 1.6)
                opacity: 1 - crt.fade

                // Halo
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 40
                    height: 40
                    radius: 20
                    color: Qt.alpha(Theme.primary, 0.25)
                    z: -1
                }
            }
        }

        // ── Insignia central: icono + texto ───────────────────────────────
        Column {
            id: badge

            readonly property var info: ({
                lock: { icon: root.p > 0.45 ? "lock" : "lock_open", text: "Bloqueando…" },
                suspend: { icon: "bedtime", text: "Buenas noches" },
                logout: { icon: "waving_hand", text: `Hasta luego, ${root.user}` },
                reboot: { icon: "restart_alt", text: "Reiniciando…" },
                poweroff: { icon: "power_settings_new", text: "Apagando…" },
                welcome: { icon: "waving_hand", text: `Hola de nuevo, ${root.user}` },
                locked: { icon: "lock", text: "" }
            })[root.scene] ?? { icon: "", text: "" }

            // Entra rebotando; en el apagado se va antes de que se cierre la imagen.
            readonly property real enter: root.scene === "welcome"
                ? root.ease(root.span(root.w, 0.2, 0.5))
                : root.ease(root.span(root.p, 0, 0.3))
            readonly property real leave: root.scene === "welcome" ? root.span(root.w, 0.75, 1)
                : root.scene === "poweroff" ? root.span(root.p, 0.25, 0.45)
                : root.scene === "lock" ? root.span(root.p, 0.85, 1)
                : root.scene === "locked" ? 1
                : root.span(root.p, 0.8, 1)

            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.scene === "welcome" ? -40 * leave : 0
            spacing: 22
            opacity: enter * (1 - leave)
            scale: 0.6 + 0.4 * enter + (root.scene === "welcome" ? 0.08 * leave : -0.1 * leave)
            visible: opacity > 0.01

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 132
                height: 132

                // Onda que se expande desde la insignia
                Rectangle {
                    readonly property real t: root.scene === "welcome" ? root.span(root.w, 0.3, 0.9) : root.span(root.p, 0.4, 0.9)
                    anchors.centerIn: parent
                    width: 132 * (1 + t * 1.6)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    opacity: (1 - t) * 0.7
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.primary }
                        GradientStop { position: 1; color: Theme.secondary }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: badge.info.icon
                        font.pixelSize: 62
                        color: Theme.textOnPrimary
                        rotation: {
                            const s = root.scene;
                            if (s === "reboot") return 360 * 1.5 * root.ease(root.p);
                            // Saludo: la mano se mece
                            if (s === "logout") return 22 * Math.sin(root.p * Math.PI * 5);
                            if (s === "welcome") return 22 * Math.sin(root.w * Math.PI * 5);
                            // La luna se acomoda despacio
                            if (s === "suspend") return -25 * root.ease(root.p);
                            return 0;
                        }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: badge.info.text
                color: "white"
                font.pixelSize: 30
                font.weight: Font.Bold
            }

            // Hora, en la bienvenida
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.scene === "welcome"
                text: Time.time
                color: Qt.alpha("white", 0.7)
                font.pixelSize: 20
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }

        // Aviso de cancelación
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 60
            visible: Power.busy && !Power.committed && root.scene !== "lock"
            width: hint.implicitWidth + 32
            height: 38
            radius: 19
            color: Qt.alpha("black", 0.55)
            border.color: Qt.alpha("white", 0.12)
            border.width: 1
            opacity: root.ease(root.span(root.p, 0, 0.2))

            StyledText {
                id: hint
                anchors.centerIn: parent
                text: "Esc o clic para cancelar"
                color: Qt.alpha("white", 0.8)
                font.pixelSize: Theme.font.small + 1
            }
        }
    }

    // Esc o clic: cancelar (solo antes de ejecutar la acción)
    MouseArea {
        anchors.fill: parent
        enabled: Power.busy && !Power.committed
        onClicked: Power.cancel()
    }
    Item {
        focus: Power.busy && !Power.committed
        Keys.onEscapePressed: Power.cancel()
    }
}
