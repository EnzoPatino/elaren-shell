import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kscreenlocker as ScreenLocker
import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.private.battery

// Pantalla de bloqueo de Elaren.
//
// La carga kscreenlocker (el bloqueador de KDE), así que la autenticación, la
// protección de la sesión y el manejo de varias pantallas siguen siendo los
// de Plasma: esto es solo la interfaz. Se instala con scripts/lockscreen.sh o
// desde Configuración → Bloqueo.
//
// kscreenlocker no corre dentro de Quickshell: no hay acceso a Theme ni a
// Config. Los colores replican los tokens de theme/Theme.qml y Elaren
// sincroniza el acento y las demás opciones en `config` (ver config.xml).
//
// Dos estados: en reposo solo se ve el reloj grande sobre el fondo; al tocar
// una tecla o el ratón el reloj sube y aparece la tarjeta con el avatar y la
// contraseña. Tras 10 s sin actividad (y sin nada escrito) vuelve al reposo.
Item {
    id: root

    // Propiedades y señales que kscreenlocker busca en la raíz
    property bool debug: false
    property string notification
    property bool viewVisible: false
    signal clearPassword()
    signal notificationRepeated()

    implicitWidth: 800
    implicitHeight: 600

    // ── Opciones (sincronizadas por Elaren) ──────────────────────────────
    // En modo prueba (`kscreenlocker_greet --testing --shell …`) puede no
    // haber `config`: entonces valen los valores por defecto.
    function option(name: string, fallback: var): var {
        const value = typeof config !== "undefined" && config ? config[name] : undefined;
        return value === undefined || value === null || value === "" ? fallback : value;
    }

    readonly property color accent: option("accent", "#a6c8ff")
    readonly property color accentSecondary: option("accentSecondary", "#cdb4ff")
    readonly property color accentOn: option("accentOn", "#0b2a52")
    readonly property real animScale: Math.max(0, Number(option("animationScale", 1)))
    readonly property bool blurWallpaper: option("blur", true) === true || option("blur", true) === "true"
    readonly property bool clockSeconds: option("clockSeconds", false) === true || option("clockSeconds", false) === "true"
    readonly property bool showMedia: option("showMedia", true) === true || option("showMedia", true) === "true"
    readonly property string avatarShape: option("avatarShape", "squircle")
    readonly property string avatarSource: {
        const custom = option("avatarImage", "");
        const path = custom || (typeof kscreenlocker_userImage !== "undefined" ? kscreenlocker_userImage : "");
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }
    readonly property string userName: typeof kscreenlocker_userName !== "undefined" ? kscreenlocker_userName : ""

    // ── Tokens (copia de theme/Theme.qml) ────────────────────────────────
    readonly property color surface: "#1e1e2e"
    readonly property color text: "#e6e1e5"
    readonly property color textMuted: "#a9a4bb"
    readonly property color warning: "#f9e2af"
    readonly property color error: "#f38ba8"
    readonly property color glass: Qt.alpha(surface, 0.62)
    readonly property color glassBorder: Qt.alpha("white", 0.09)
    readonly property string fontFamily: "Inter, Noto Sans, sans-serif"
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property int fast: 150 * animScale
    readonly property int normal: 280 * animScale
    readonly property int slow: 450 * animScale
    readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> expressive: [0.38, 1.21, 0.22, 1, 1, 1]

    // ── Estado ───────────────────────────────────────────────────────────
    property bool uiVisible: false
    // 0 = reposo (solo reloj) … 1 = tarjeta de contraseña
    property real ui: uiVisible ? 1 : 0
    Behavior on ui { NumberAnimation { duration: root.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasizedDecel } }

    // Esperando la respuesta de PAM tras enviar la contraseña
    property bool waiting: false
    property bool rejected: false
    readonly property bool graceLocked: graceTimer.running || (authenticator.graceLocked ?? false)

    property date now: new Date()

    function wake(): void {
        if (!uiVisible) uiVisible = true;
        idleTimer.restart();
    }

    function sleep(): void {
        uiVisible = false;
        PasswordSync.password = "";
    }

    function submit(): void {
        if (!uiVisible || graceLocked || waiting) return;
        waiting = true;
        authenticator.respond(PasswordSync.password);
    }

    onUiVisibleChanged: {
        if (uiVisible) {
            Window.window?.requestActivate();
            idleTimer.restart();
        }
        authenticator.startAuthenticating();
    }

    onClearPassword: {
        PasswordSync.password = "";
        input.forceActiveFocus();
    }
    onNotificationRepeated: messageBounce.restart()

    Component.onCompleted: {
        authenticator.startAuthenticating();
        input.forceActiveFocus();
    }

    Connections {
        target: authenticator

        function onFailed(kind: int): void {
            // Los autenticadores no interactivos (huella, tarjeta) avisan
            // con su propio mensaje; solo la contraseña sacude la tarjeta.
            if (kind !== 0) return;
            root.waiting = false;
            root.rejected = true;
            root.notification = "Contraseña incorrecta";
            shake.restart();
            graceTimer.restart();
            notificationTimer.restart();
        }

        function onSucceeded(): void {
            root.waiting = false;
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                // Sesión sin contraseña: confirmar con un botón
                root.noPassword = true;
                root.wake();
            }
        }

        function onInfoMessageChanged(): void {
            if (authenticator.infoMessage) root.notification = authenticator.infoMessage;
            notificationTimer.restart();
        }

        function onErrorMessageChanged(): void {
            if (authenticator.errorMessage) root.notification = authenticator.errorMessage;
            notificationTimer.restart();
        }

        function onPromptForSecretChanged(): void {
            input.forceActiveFocus();
        }
    }

    property bool noPassword: false

    SessionManagement {
        id: session
        onAboutToSuspend: root.clearPassword()
    }

    KeyboardIndicator.KeyState {
        id: capsLock
        key: Qt.Key_CapsLock
    }

    BatteryControlModel {
        id: battery
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: idleTimer
        interval: 10000
        onTriggered: {
            if (PasswordSync.password.length === 0 && !root.waiting && !root.noPassword) root.sleep();
            else restart();
        }
    }

    Timer {
        id: graceTimer
        interval: 3000
        onTriggered: {
            root.rejected = false;
            PasswordSync.password = "";
            authenticator.startAuthenticating();
            input.forceActiveFocus();
        }
    }

    Timer {
        id: notificationTimer
        interval: 3500
        onTriggered: root.notification = ""
    }

    // ── Fondo ────────────────────────────────────────────────────────────
    // `wallpaper` es el fondo que dibuja kscreenlocker; acá se desenfoca y
    // oscurece un poco más cuando aparece la tarjeta.
    MultiEffect {
        anchors.fill: parent
        source: typeof wallpaper !== "undefined" ? wallpaper : null
        visible: source !== null
        autoPaddingEnabled: false
        blurEnabled: root.blurWallpaper
        blurMax: 64
        blur: 0.35 + 0.65 * root.ui
        saturation: -0.1 * root.ui
        brightness: -0.08 - 0.1 * root.ui
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("black", 0.35) }
            GradientStop { position: 0.55; color: Qt.alpha("black", 0.12 + 0.2 * root.ui) }
            GradientStop { position: 1; color: Qt.alpha("black", 0.5) }
        }
    }

    // Brillo de acento detrás de la tarjeta
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.y + card.height / 2 - height / 2
        width: Math.min(root.width, 900)
        height: width * 0.7
        radius: width / 2
        opacity: 0.22 * root.ui
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.35; color: Qt.alpha(root.accent, 0.5) }
            GradientStop { position: 0.65; color: Qt.alpha(root.accentSecondary, 0.5) }
            GradientStop { position: 1; color: "transparent" }
        }
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 1 }
    }

    // ── Entrada: cualquier movimiento o clic despierta la interfaz ───────
    MouseArea {
        id: catcher

        property bool seenMove: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onPressed: {
            root.wake();
            input.forceActiveFocus();
        }
        // El primer evento de movimiento llega al crear la ventana; recién
        // a partir del segundo es la persona moviendo el ratón.
        onPositionChanged: {
            if (seenMove) root.wake();
            seenMove = true;
        }
    }

    // ── Reloj ────────────────────────────────────────────────────────────
    Column {
        id: clock

        readonly property real idleY: root.height / 2 - height / 2 - root.height * 0.04
        readonly property real activeY: Math.max(root.height * 0.07, card.y - height - root.height * 0.07)

        anchors.horizontalCenter: parent.horizontalCenter
        y: idleY + (activeY - idleY) * root.ui
        scale: 1 - 0.38 * root.ui
        transformOrigin: Item.Bottom
        spacing: 2

        Row {
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: timeText
                text: Qt.formatTime(root.now, "HH:mm")
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: Math.round(Math.min(root.height * 0.2, 190))
                font.weight: Font.Light
                font.letterSpacing: -2
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha("black", 0.55); shadowBlur: 0.8; shadowVerticalOffset: 3 }
            }
            Text {
                anchors.baseline: timeText.baseline
                visible: root.clockSeconds
                leftPadding: 8
                text: Qt.formatTime(root.now, "ss")
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Math.round(timeText.font.pixelSize * 0.28)
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const s = Qt.locale("es_AR").toString(root.now, "dddd d 'de' MMMM");
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: Qt.alpha(root.text, 0.9)
            font.family: root.fontFamily
            font.pixelSize: Math.round(Math.max(16, timeText.font.pixelSize * 0.14))
            font.weight: Font.Medium
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha("black", 0.6); shadowBlur: 0.6 }
        }
    }

    // Pista en reposo
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        text: "Escribí tu contraseña o tocá para desbloquear"
        color: Qt.alpha(root.text, 0.7)
        font.family: root.fontFamily
        font.pixelSize: 13
        opacity: (1 - root.ui) * (0.55 + 0.45 * hintPulse.value)

        QtObject {
            id: hintPulse
            property real value: 0
            SequentialAnimation on value {
                running: !root.uiVisible && root.animScale > 0
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 1600; easing.type: Easing.InOutSine }
            }
        }
    }

    // ── Tarjeta ──────────────────────────────────────────────────────────
    Item {
        id: card

        property real shakeX: 0

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: shakeX
        y: root.height * 0.5 - height * 0.32 + 36 * (1 - root.ui)
        width: Math.min(root.width - 32, 380)
        height: cardColumn.implicitHeight + 56
        opacity: root.ui
        scale: 0.94 + 0.06 * root.ui
        // Siempre visible y habilitada, aunque esté transparente: si no, el
        // campo de contraseña pierde el foco y escribir no despierta nada.
        // Los clics mientras está oculta los frena `cardShield`.

        SequentialAnimation {
            id: shake
            NumberAnimation { target: card; property: "shakeX"; to: -14; duration: 50 }
            NumberAnimation { target: card; property: "shakeX"; to: 12; duration: 70 }
            NumberAnimation { target: card; property: "shakeX"; to: -8; duration: 70 }
            NumberAnimation { target: card; property: "shakeX"; to: 5; duration: 60 }
            NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 60 }
        }

        Rectangle {
            anchors.fill: parent
            radius: 28
            color: root.glass
            border.color: root.glassBorder
            border.width: 1
        }
        // Reflejo superior del vidrio
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 27
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha("white", 0.06) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        Column {
            id: cardColumn

            anchors.top: parent.top
            anchors.topMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 56
            spacing: 14

            // Avatar con la forma elegida en Elaren
            Item {
                id: avatar

                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                scale: 0.8 + 0.2 * root.ui

                // Anillo de acento que gira despacio mientras se verifica
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 10
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: root.rejected ? root.error : root.accent
                    opacity: root.waiting ? 0.9 : 0.35
                    Behavior on opacity { NumberAnimation { duration: root.normal } }
                    Behavior on border.color { ColorAnimation { duration: root.normal } }
                    visible: root.avatarShape === "circle"
                }

                Item {
                    id: avatarContent
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.accent }
                            GradientStop { position: 1; color: root.accentSecondary }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: root.userName.charAt(0).toUpperCase()
                        color: root.accentOn
                        font.family: root.fontFamily
                        font.pixelSize: 42
                        font.weight: Font.Bold
                    }
                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: root.avatarSource
                        sourceSize: Qt.size(192, 192)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Item {
                    id: avatarMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "white"
                            strokeWidth: -1
                            PathPolyline { path: root.shapePoints(root.avatarShape, avatar.width) }
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: avatarContent
                    maskEnabled: true
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const h = root.now.getHours();
                    const hello = h < 6 ? "Buenas noches" : h < 13 ? "Buen día" : h < 20 ? "Buenas tardes" : "Buenas noches";
                    return root.userName ? `${hello}, ${root.userName}` : hello;
                }
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }

            // Campo de contraseña: la entrada real es invisible y se dibujan
            // puntitos que aparecen con un pequeño rebote.
            Rectangle {
                id: field

                visible: !root.noPassword
                width: parent.width
                height: 48
                radius: 24
                color: Qt.alpha("white", input.activeFocus ? 0.1 : 0.07)
                border.width: 1
                border.color: root.rejected ? root.error
                    : input.activeFocus ? Qt.alpha(root.accent, 0.7) : Qt.alpha("white", 0.1)
                opacity: root.graceLocked ? 0.6 : 1

                Behavior on border.color { ColorAnimation { duration: root.normal } }
                Behavior on color { ColorAnimation { duration: root.fast } }

                Text {
                    id: lockIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    text: capsLock.locked ? "keyboard_capslock" : "lock"
                    color: capsLock.locked ? root.warning : root.textMuted
                    font.family: root.iconFont
                    font.pixelSize: 19
                }

                TextInput {
                    id: input

                    anchors.left: lockIcon.right
                    anchors.leftMargin: 10
                    anchors.right: submitButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    cursorVisible: false
                    cursorDelegate: Item {}
                    font.pixelSize: 15
                    focus: true
                    enabled: !root.graceLocked
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    text: PasswordSync.password
                    onTextEdited: {
                        PasswordSync.password = text;
                        root.rejected = false;
                    }

                    // Antes de que el campo procese la tecla: despertar la
                    // interfaz (la tecla igual se escribe).
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            // Con la interfaz oculta, Esc lo usa kscreenlocker
                            // para apagar la pantalla.
                            if (root.uiVisible) {
                                root.sleep();
                                event.accepted = true;
                            }
                            return;
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.uiVisible) root.submit();
                            else root.wake();
                            event.accepted = true;
                            return;
                        }
                        root.wake();
                        event.accepted = false;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: input.left
                    visible: PasswordSync.password.length === 0
                    text: root.graceLocked ? "Esperá un momento…" : "Contraseña"
                    color: Qt.alpha(root.textMuted, 0.85)
                    font.family: root.fontFamily
                    font.pixelSize: 14
                }

                Row {
                    id: dots
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: input.left
                    spacing: 6
                    clip: true
                    width: input.width

                    Repeater {
                        model: Math.min(PasswordSync.password.length, Math.floor(dots.width / 14))

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: root.rejected ? root.error : root.text
                            Behavior on color { ColorAnimation { duration: root.fast } }

                            NumberAnimation on scale {
                                from: 0
                                to: 1
                                duration: 220 * root.animScale
                                easing.type: Easing.OutBack
                                easing.overshoot: 3
                            }
                        }
                    }
                }

                // Botón de enviar; gira mientras PAM responde.
                Rectangle {
                    id: submitButton

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: PasswordSync.password.length > 0 ? root.accent : Qt.alpha("white", 0.08)
                    scale: submitTouch.pressed ? 0.88 : 1

                    Behavior on color { ColorAnimation { duration: root.normal } }
                    Behavior on scale { NumberAnimation { duration: root.fast; easing.type: Easing.OutBack } }

                    Text {
                        id: submitIcon
                        anchors.centerIn: parent
                        text: root.waiting ? "progress_activity" : "arrow_forward"
                        color: PasswordSync.password.length > 0 ? root.accentOn : root.textMuted
                        font.family: root.iconFont
                        font.pixelSize: 20

                        RotationAnimation on rotation {
                            running: root.waiting
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) submitIcon.rotation = 0
                        }
                    }

                    MouseArea {
                        id: submitTouch
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.submit();
                            input.forceActiveFocus();
                        }
                    }
                }
            }

            // Sin contraseña: un botón para entrar
            Rectangle {
                visible: root.noPassword
                width: parent.width
                height: 48
                radius: 24
                color: root.accent

                Text {
                    anchors.centerIn: parent
                    text: "Desbloquear"
                    color: root.accentOn
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }

            // Avisos: Bloq Mayús, error, huella/tarjeta
            Text {
                id: message

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: {
                    const parts = [];
                    if (root.notification) parts.push(root.notification);
                    if (capsLock.locked) parts.push("Bloq Mayús activado");
                    const types = authenticator.authenticatorTypes ?? 0;
                    if (!root.notification && (types & ScreenLocker.Authenticator.Fingerprint)) parts.push("o apoyá el dedo en el lector");
                    if (!root.notification && (types & ScreenLocker.Authenticator.Smartcard)) parts.push("o usá tu tarjeta");
                    return parts.join(" · ");
                }
                color: root.rejected ? root.error : capsLock.locked ? root.warning : root.textMuted
                font.family: root.fontFamily
                font.pixelSize: 13
                visible: text !== ""

                SequentialAnimation {
                    id: messageBounce
                    NumberAnimation { target: message; property: "scale"; to: 1.08; duration: 90 }
                    NumberAnimation { target: message; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
                }
            }
        }

        // Con la interfaz oculta, los botones transparentes no deben
        // responder: un clic acá solo la despierta.
        MouseArea {
            id: cardShield
            anchors.fill: parent
            z: 100
            visible: !root.uiVisible
            // Sin hover: el movimiento sigue llegando a `catcher`, que despierta.
            hoverEnabled: false
            cursorShape: Qt.BlankCursor
            onPressed: {
                root.wake();
                input.forceActiveFocus();
            }
        }
    }

    // ── Música ───────────────────────────────────────────────────────────
    Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.y + card.height + 18
        width: card.width
        active: root.showMedia
        opacity: root.ui
        visible: opacity > 0.01
        source: "MediaPill.qml"
        onLoaded: {
            item.accent = Qt.binding(() => root.accent);
            item.accentOn = Qt.binding(() => root.accentOn);
            item.text = Qt.binding(() => root.text);
            item.textMuted = Qt.binding(() => root.textMuted);
            item.glass = Qt.binding(() => root.glass);
            item.glassBorder = Qt.binding(() => root.glassBorder);
            item.fontFamily = Qt.binding(() => root.fontFamily);
            item.iconFont = Qt.binding(() => root.iconFont);
        }
    }

    // ── Barra inferior: acciones y estado ────────────────────────────────
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 8
        opacity: root.ui
        visible: opacity > 0.01

        Pill {
            visible: session.canSuspend
            icon: "bedtime"
            label: "Suspender"
            onClicked: session.suspend()
        }
        Pill {
            visible: session.canHibernate
            icon: "mode_standby"
            label: "Hibernar"
            onClicked: session.hibernate()
        }
        Pill {
            visible: session.canSwitchUser
            icon: "switch_account"
            label: "Cambiar de usuario"
            onClicked: session.switchUser()
        }
        Pill {
            id: layoutPill
            visible: layoutSwitcher.hasMultipleKeyboardLayouts
            icon: "keyboard"
            label: layoutSwitcher.layoutNames.shortName ?? ""
            onClicked: layoutSwitcher.keyboardLayout.switchToNextLayout()

            PW.KeyboardLayoutSwitcher {
                id: layoutSwitcher
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 8
        opacity: 0.55 + 0.45 * root.ui

        Pill {
            visible: battery.hasInternalBatteries
            interactive: false
            icon: {
                const p = battery.percent;
                if (battery.pluggedIn) return "battery_charging_full";
                if (p >= 95) return "battery_full";
                const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar"];
                return steps[Math.min(6, Math.floor(p / 15))];
            }
            iconColor: battery.pluggedIn ? "#a6e3a1" : battery.percent <= 15 ? root.error : root.text
            label: battery.percent + "%"
        }
    }

    // Formas del avatar (las mismas que en la isla de la barra)
    function shapePoints(shape: string, size: real): list<point> {
        const r = size / 2;
        const points = [];
        const steps = 96;
        for (let i = 0; i <= steps; i++) {
            const t = i / steps * Math.PI * 2;
            let x, y;
            if (shape === "flower") {
                const k = r * (0.88 + 0.12 * Math.cos(8 * t));
                x = Math.cos(t) * k;
                y = Math.sin(t) * k;
            } else if (shape === "hexagon") {
                // Hexágono con esquinas redondeadas (superelipse en 6 lados)
                const seg = Math.PI / 3;
                const a = ((t + seg / 2) % seg) - seg / 2;
                const k = r * Math.cos(seg / 2) / Math.cos(a) * (1 - 0.06 * Math.pow(Math.cos(3 * t), 8));
                x = Math.cos(t) * k;
                y = Math.sin(t) * k;
            } else if (shape === "circle") {
                x = Math.cos(t) * r;
                y = Math.sin(t) * r;
            } else {
                // Squircle: superelipse n = 4
                const c = Math.cos(t), s = Math.sin(t);
                x = Math.sign(c) * Math.pow(Math.abs(c), 0.5) * r;
                y = Math.sign(s) * Math.pow(Math.abs(s), 0.5) * r;
            }
            points.push(Qt.point(r + x, r + y));
        }
        return points;
    }

    // Píldora de vidrio con icono y texto
    component Pill: Rectangle {
        id: pill

        property string icon
        property string label
        property color iconColor: root.text
        property bool interactive: true
        signal clicked()

        height: 38
        width: pillRow.implicitWidth + 28
        radius: 19
        color: pillTouch.containsMouse ? Qt.alpha(root.surface, 0.8) : root.glass
        border.color: root.glassBorder
        border.width: 1
        scale: pillTouch.pressed ? 0.94 : 1

        Behavior on color { ColorAnimation { duration: root.fast } }
        Behavior on scale { NumberAnimation { duration: root.fast; easing.type: Easing.OutBack } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                color: pill.iconColor
                font.family: root.iconFont
                font.pixelSize: 18
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: pill.label
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: pillTouch
            anchors.fill: parent
            enabled: pill.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                pill.clicked();
                input.forceActiveFocus();
            }
        }
    }
}
