// ┌─ NO TOCAR ───────────────────────────────────────────────────────────┐
// │ Pantalla de bloqueo de Hyprland (ext-session-lock). Funciona y está  │
// │ terminada: no la cambies, ni la reemplaces ni la "simplifiques" sin  │
// │ que el autor lo pida explícitamente. La de Plasma es otra, aparte    │
// │ (lockscreen/org.elaren.lockscreen).                                  │
// │ Archivos: modules/lock/ (LockSurface.qml, SessionLockScreen.qml,     │
// │ qmldir) y services/SessionLock.qml.                                  │
// └──────────────────────────────────────────────────────────────────────┘

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Lo que se ve en cada pantalla mientras la sesión está bloqueada en
// Hyprland. Diseño "Vinilo": la música es la protagonista.
//
//   Reposo:    la hora arriba y, en el centro, el disco girando con la
//              portada (o un reloj analógico si no suena nada).
//   Despierta: la hora sube y se achica, el disco sube un poco y aparece el
//              espectro en anillo; debajo, el tema y sus controles, y abajo
//              el usuario y la contraseña. En las esquinas, clima y batería.
//
// Fluidez: todo el paso de reposo a despierta lo mueve un único valor
// animado (`ui`, de 0 a 1) a través de posición, escala y opacidad, que no
// rehacen el texto ni el diseño. Lo que no se ve no trabaja: el disco gira
// solo con música sonando, el espectro (cava) corre solo despierta y con
// música (ver SessionLockScreen), y el reloj analógico sin segundero se
// redibuja una vez por minuto.
Item {
    id: root

    // modules/lock/SessionLockScreen.qml: PAM, mensajes y estado despierta
    required property var lock

    readonly property real animScale: Theme.userAnim.scale
    // Con la escala elegida por la persona, no la del modo gaming.
    property real ui: lock.awake ? 1 : 0
    Behavior on ui { Anim { duration: Theme.userAnim.slow; easing.bezierCurve: Theme.userAnim.emphasizedDecel } }

    property real media: lock.showMedia ? 1 : 0
    Behavior on media { Anim { duration: Theme.userAnim.slow } }

    // Medida base: así el diseño vale igual en un monitor vertical.
    readonly property real unit: Math.min(width, height)
    readonly property color accent: lock.showMedia ? Media.accent : Theme.primary

    function wake(): void {
        lock.wake();
        input.forceActiveFocus();
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
        // Recién con el tamaño de la superficie: con 0×0 se decodificaba el
        // fondo entero y después otra vez al tamaño real.
        readonly property bool sized: root.width > 0 && root.height > 0
        source: sized ? Wallpaper.source : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // Del tamaño de la pantalla en píxeles físicos: un fondo 8K no ocupa
        // memoria de más y en HiDPI no se ve borroso.
        sourceSize: Qt.size(Math.ceil(root.width * Screen.devicePixelRatio), Math.ceil(root.height * Screen.devicePixelRatio))
        visible: !Config.lockscreenBlur
        onStatusChanged: if (status === Image.Error || status === Image.Ready)
            console.info("sessionlock: fondo", status === Image.Ready ? "cargado" : "con error", source)
        Component.onCompleted: if (Wallpaper.source === "") console.warn("sessionlock: sin fondo (Wallpaper.source vacío)")
    }

    // Desenfoque fijo: animarlo recalcularía el blur de toda la pantalla en
    // cada cuadro. El cambio entre reposo y despierta lo da el velo.
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: Config.lockscreenBlur && wallpaper.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: 0.8
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        opacity: 0.18 + 0.3 * root.ui
    }

    // ── Entrada: cualquier movimiento o clic despierta la interfaz ───────
    MouseArea {
        property bool seenMove: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.lock.awake ? Qt.ArrowCursor : Qt.BlankCursor
        onPressed: root.wake()
        // El primer movimiento llega al crear la superficie; recién a partir
        // del segundo es la persona moviendo el ratón.
        onPositionChanged: {
            if (seenMove) root.wake();
            seenMove = true;
        }
    }

    // ── Hora ─────────────────────────────────────────────────────────────
    // Propio: Time solo se actualiza por minuto y acá puede haber segundos.
    SystemClock {
        id: lockClock
        precision: Config.lockscreenClockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (0.15 - 0.08 * root.ui) - height / 2
        scale: 1 - 0.45 * root.ui
        spacing: root.unit * 0.004

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(lockClock.date, Config.lockscreenClockSeconds ? "HH:mm:ss" : "HH:mm")
            color: Theme.text
            font.pixelSize: root.unit * 0.13
            font.weight: Font.Light
            font.letterSpacing: -root.unit * 0.003
            font.features: { "tnum": 1 }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.longDate
            color: Theme.textMuted
            font.pixelSize: root.unit * 0.022
            font.capitalization: Font.Capitalize
            // La fecha se va al despertar: arriba queda solo la hora.
            opacity: 1 - root.ui
        }
    }

    // ── Disco ────────────────────────────────────────────────────────────
    Item {
        id: stage

        readonly property real disc: root.unit * 0.36

        width: disc * 1.6
        height: width
        x: (root.width - width) / 2
        y: root.height * (0.54 - 0.13 * root.ui) - height / 2
        scale: 0.88 + 0.12 * root.ui

        // Espectro en anillo: solo despierta y con música.
        RadialSpectrum {
            anchors.fill: parent
            active: root.ui > 0 && root.media > 0 && Media.playing
            visible: opacity > 0.01
            opacity: root.ui * root.media
            values: Visualizer.display
            innerRadius: stage.disc * 0.56
            reach: stage.disc * 0.17
            color: root.accent
        }

        Vinyl {
            // El componente reserva a la derecha el lugar del brazo: el disco
            // queda centrado y el brazo sobresale.
            x: (parent.width - stage.disc) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: stage.disc / 0.86
            height: stage.disc
            visible: opacity > 0.01
            opacity: root.media
            active: visible
            spinning: Media.playing
            // La copia local que ya bajó Media: el bloqueo no descarga nada.
            cover: Media.artLocal
            accent: root.accent
            animScale: root.animScale
            level: Visualizer.users ? Visualizer.level : 0
            progress: Media.progress
            // En reposo el clic solo despierta: no pausa la música.
            onClicked: {
                if (root.lock.awake) Media.togglePlaying();
                root.wake();
            }
        }

        Loader {
            anchors.centerIn: parent
            width: stage.disc * 0.92
            height: width
            active: root.media < 1
            visible: active
            opacity: 1 - root.media

            sourceComponent: AnalogClock {
                now: lockClock.date
                showSeconds: Config.lockscreenClockSeconds
                faceColor: Qt.alpha(Theme.surface, 0.45)
                animScale: root.animScale
            }
        }
    }

    // ── Tema que suena ───────────────────────────────────────────────────
    Column {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.y + stage.height * (0.5 + 0.5 * stage.scale) - root.unit * 0.02 + root.unit * 0.03 * (1 - root.ui)
        width: Math.min(root.width - 64, root.unit * 0.6)
        spacing: root.unit * 0.006
        visible: opacity > 0.01
        opacity: root.ui * root.media

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Media.title
            color: Theme.text
            font.pixelSize: root.unit * 0.024
            font.weight: Font.DemiBold
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: text !== ""
            text: Media.artist
            color: Theme.textMuted
            font.pixelSize: root.unit * 0.017
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: root.unit * 0.008
            spacing: root.unit * 0.03

            Repeater {
                // Modelo fijo: si dependiera de Media.playing, cada cambio
                // rehacía los tres botones (sin animación ni hover).
                model: ["previous", "toggle", "next"]

                MaterialIcon {
                    required property string modelData
                    required property int index

                    function run(): void {
                        if (modelData === "previous") Media.previous();
                        else if (modelData === "next") Media.next();
                        else Media.togglePlaying();
                    }

                    text: modelData === "previous" ? "skip_previous"
                        : modelData === "next" ? "skip_next"
                        : Media.playing ? "pause" : "play_arrow"
                    color: hover.hovered ? root.accent : Theme.text
                    font.pixelSize: root.unit * (index === 1 ? 0.04 : 0.03)
                    animateChange: root.animScale > 0

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    // Sin tomar el foco: la contraseña lo conserva.
                    TapHandler {
                        onTapped: {
                            parent.run();
                            root.wake();
                        }
                    }
                }
            }
        }
    }

    // ── Usuario y contraseña ─────────────────────────────────────────────
    Column {
        id: login

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - root.unit * 0.07 + root.unit * 0.04 * (1 - root.ui)
        width: Math.min(root.width - 32, root.unit * 0.38)
        spacing: Theme.spacing.large
        // Siempre "visible" aunque esté transparente: si no, el campo pierde
        // el foco y escribir no despertaría la interfaz.
        opacity: root.ui

        Rectangle {
            width: parent.width
            height: 46
            radius: Theme.radius.full
            color: Qt.alpha(Theme.surface, input.activeFocus ? 0.7 : 0.55)
            border.color: root.lock.messageIsError && root.lock.message !== ""
                ? Qt.alpha(Theme.error, 0.7) : Qt.alpha(root.accent, input.activeFocus ? 0.5 : 0.2)
            border.width: 1

            Behavior on border.color { CAnim {} }

            // La foto de la persona hace de candado.
            Avatar {
                id: lockIcon
                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                shape: Config.barAvatarShape
                animated: root.animScale > 0
            }

            MaterialIcon {
                id: busyIcon
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: root.lock.authenticating
                text: "hourglass_top"
                color: Theme.textMuted
                font.pixelSize: Theme.font.icon
                animateChange: false
            }

            TextInput {
                id: input

                anchors.left: lockIcon.right
                anchors.leftMargin: 10
                anchors.right: busyIcon.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: Theme.text
                selectionColor: "transparent"
                selectedTextColor: Theme.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.large
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
                        root.lock.sleep();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.lock.awake) root.lock.submit();
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
                text: root.lock.authenticating ? "Verificando…"
                    : root.lock.awaitingResponse ? "Respuesta"
                    : `Contraseña de ${Quickshell.env("USER") ?? ""}`
                color: Qt.alpha(Theme.textMuted, 0.85)
                font.pixelSize: Theme.font.normal + 1
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

    // Con la interfaz oculta, un clic sobre el campo transparente solo
    // despierta. Sin hover: el movimiento sigue llegando al de abajo. Fuera
    // de la columna: adentro, su alto dependería del de ella (bucle de layout).
    MouseArea {
        x: login.x
        y: login.y
        width: login.width
        height: login.height
        visible: !root.lock.awake
        hoverEnabled: false
        cursorShape: Qt.BlankCursor
        onPressed: root.wake()
    }

    // ── Esquinas: clima y batería ────────────────────────────────────────
    // El clima solo si ya está cargado (widget de clima activo): el bloqueo
    // no consulta nada en la red por su cuenta.
    // Ancho máximo: lo que queda al costado de la columna de la contraseña,
    // así en un monitor vertical no se le montan encima.
    readonly property real cornerWidth: Math.max(0, (root.width - login.width) / 2 - root.unit * 0.05 - Theme.spacing.large)

    component Corner: Row {
        property string icon
        property string label

        y: root.height - height - root.unit * 0.04
        spacing: Theme.spacing.normal
        visible: opacity > 0.01
        opacity: root.ui * 0.85

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icon
            color: Theme.textMuted
            font.pixelSize: Theme.font.icon
            animateChange: false
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(0, root.cornerWidth - Theme.font.icon - parent.spacing))
            elide: Text.ElideRight
            text: parent.label
            color: Theme.textMuted
            font.pixelSize: Theme.font.normal
        }
    }

    Corner {
        x: root.unit * 0.05
        visible: Weather.current !== null && opacity > 0.01
        icon: Weather.current ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"
        label: Weather.current ? `${Math.round(Weather.current.temp)}° · ${Weather.describe(Weather.current.code)}` : ""
    }

    Corner {
        x: root.width - width - root.unit * 0.05
        visible: Battery.available && opacity > 0.01
        icon: Battery.icon
        label: `${Math.round(Battery.level * 100)}%`
    }

    // Pista en reposo
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.unit * 0.05
        visible: opacity > 0.01
        opacity: 0.6 * (1 - root.ui)
        text: "Escribí tu contraseña o mové el ratón"
        color: Theme.text
        font.pixelSize: Theme.font.normal
    }
}
