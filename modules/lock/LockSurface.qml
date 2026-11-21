import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Lo que se ve en cada pantalla mientras la sesión está bloqueada en
// Hyprland. Mismo diseño que la pantalla de Plasma
// (lockscreen/org.elaren.lockscreen): en reposo solo el reloj grande sobre el
// fondo; al tocar una tecla o el ratón el reloj sube y aparece la tarjeta con
// el avatar y la contraseña. Tras 10 s sin actividad (y sin nada escrito)
// vuelve al reposo.
Item {
    id: root

    // modules/lock/SessionLockScreen.qml: PAM y mensajes
    required property var lock

    readonly property real animScale: Theme.userAnim.scale
    property bool uiVisible: false
    property real ui: uiVisible ? 1 : 0
    // Con la escala elegida por la persona, no la del modo gaming.
    Behavior on ui { Anim { duration: Theme.userAnim.slow; easing.bezierCurve: Theme.userAnim.emphasizedDecel } }

    function wake(): void {
        uiVisible = true;
        idleTimer.restart();
        input.forceActiveFocus();
    }

    function sleep(): void {
        uiVisible = false;
        SessionLock.password = "";
    }

    Timer {
        id: idleTimer
        interval: 10000
        onTriggered: if (SessionLock.password === "" && !root.lock.authenticating) root.uiVisible = false
    }

    Component.onCompleted: input.forceActiveFocus()

    // ── Fondo ────────────────────────────────────────────────────────────
    // Sin imagen (en Hyprland el fondo puede no resolverse desde la config
    // de Plasma) no queda una superficie lisa casi negra: degradé de acento.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.darker(Theme.primary, 2.2) }
            GradientStop { position: 0.55; color: Theme.surface }
            GradientStop { position: 1; color: Qt.darker(Theme.secondary, 2.4) }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: Wallpaper.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: !Config.lockscreenBlur
        onStatusChanged: if (status === Image.Error || status === Image.Ready)
            console.info("sessionlock: fondo", status === Image.Ready ? "cargado" : "con error", source)
        Component.onCompleted: if (Wallpaper.source === "") console.warn("sessionlock: sin fondo (Wallpaper.source vacío)")
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: Config.lockscreenBlur && wallpaper.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: 0.6 + 0.4 * root.ui
        autoPaddingEnabled: false
    }

    // Oscurece más cuando aparece la tarjeta, para que se lea bien.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.12 + 0.2 * root.ui
    }

    // ── Entrada: cualquier movimiento o clic despierta la interfaz ───────
    MouseArea {
        property bool seenMove: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onPressed: root.wake()
        // El primer movimiento llega al crear la superficie; recién a partir
        // del segundo es la persona moviendo el ratón.
        onPositionChanged: {
            if (seenMove) root.wake();
            seenMove = true;
        }
    }

    // ── Reloj ────────────────────────────────────────────────────────────
    // Propio: Time solo se actualiza por minuto y acá puede haber segundos.
    SystemClock {
        id: lockClock
        precision: Config.lockscreenClockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (0.34 - 0.16 * root.ui) - height / 2
        spacing: 4
        scale: 1 - 0.35 * root.ui

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(lockClock.date, Config.lockscreenClockSeconds ? "HH:mm:ss" : "HH:mm")
            color: Theme.text
            font.pixelSize: 112
            font.weight: Font.Bold
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.longDate
            color: Qt.alpha(Theme.text, 0.85)
            font.pixelSize: 22
            font.capitalization: Font.Capitalize
        }
    }

    // ── Tarjeta ──────────────────────────────────────────────────────────
    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.5 - height * 0.2 + 36 * (1 - root.ui)
        width: Math.min(root.width - 32, 380)
        height: cardColumn.implicitHeight + 56
        radius: Theme.radius.large * 2
        color: Qt.alpha(Theme.surface, 0.62)
        border.color: Theme.glassBorder
        border.width: 1
        opacity: root.ui
        scale: 0.94 + 0.06 * root.ui
        // Siempre "visible" aunque esté transparente: si no, el campo pierde
        // el foco y escribir no despertaría la interfaz.

        Column {
            id: cardColumn
            anchors.centerIn: parent
            width: parent.width - 56
            spacing: Theme.spacing.large

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                shape: Config.barAvatarShape
                animated: root.animScale > 0
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER") ?? ""
                color: Theme.text
                font.pixelSize: Theme.font.large + 3
                font.weight: Font.DemiBold
            }

            // Campo de contraseña
            Rectangle {
                width: parent.width
                height: 46
                radius: Theme.radius.full
                color: Qt.alpha("white", input.activeFocus ? 0.1 : 0.06)
                border.color: root.lock.messageIsError && root.lock.message !== ""
                    ? Qt.alpha(Theme.error, 0.7) : Qt.alpha(Theme.primary, input.activeFocus ? 0.5 : 0.2)
                border.width: 1

                MaterialIcon {
                    id: lockIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lock.authenticating ? "hourglass_top" : "lock"
                    color: Theme.textMuted
                    font.pixelSize: 19
                }

                TextInput {
                    id: input

                    anchors.left: lockIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: Theme.text
                    selectionColor: "transparent"
                    selectedTextColor: Theme.text
                    font.family: Theme.font.family
                    font.pixelSize: 15
                    focus: true
                    readOnly: root.lock.authenticating
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    text: SessionLock.password
                    onTextEdited: {
                        SessionLock.password = text;
                        root.lock.message = "";
                    }

                    // Antes de que el campo procese la tecla: despertar la
                    // interfaz (la tecla igual se escribe).
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.sleep();
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.uiVisible) root.lock.submit();
                            else root.wake();
                            event.accepted = true;
                            return;
                        }
                        root.wake();
                        event.accepted = false;
                    }
                }

                StyledText {
                    anchors.left: input.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SessionLock.password.length === 0
                    text: root.lock.authenticating ? "Verificando…" : "Contraseña"
                    color: Qt.alpha(Theme.textMuted, 0.85)
                    font.pixelSize: 14
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text !== ""
                text: root.lock.message
                color: root.lock.messageIsError ? Theme.error : Theme.textMuted
                font.pixelSize: Theme.font.normal
            }
        }

        // Con la interfaz oculta, un clic sobre la tarjeta transparente solo
        // la despierta. Sin hover: el movimiento sigue llegando al de abajo.
        MouseArea {
            anchors.fill: parent
            visible: !root.uiVisible
            hoverEnabled: false
            cursorShape: Qt.BlankCursor
            onPressed: root.wake()
        }
    }

    // Pista en reposo
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        opacity: 0.7 * (1 - root.ui)
        text: "Escribí tu contraseña o mové el ratón"
        color: Theme.text
        font.pixelSize: Theme.font.normal
    }
}
