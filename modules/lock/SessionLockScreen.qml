// ┌─ NO TOCAR ───────────────────────────────────────────────────────────┐
// │ Pantalla de bloqueo de Hyprland (ext-session-lock). Funciona y está  │
// │ terminada: no la cambies, ni la reemplaces ni la "simplifiques" sin  │
// │ que el autor lo pida explícitamente. La de Plasma es otra, aparte    │
// │ (lockscreen/org.elaren.lockscreen).                                  │
// │ Archivos: modules/lock/ (LockSurface.qml, SessionLockScreen.qml,     │
// │ qmldir) y services/SessionLock.qml.                                  │
// └──────────────────────────────────────────────────────────────────────┘

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../../config"
import "../../theme"
import "../../services"
import "."

// Bloqueo de sesión con ext-session-lock (Hyprland). Lo carga shell.qml solo
// si SessionLock.supported, así en Plasma no hacen falta los módulos de PAM
// ni de bloqueo de Quickshell.
//
// Seguridad: mientras `locked` es verdadero, el compositor no muestra nada
// más que estas superficies. Si la shell se cae estando bloqueada, la sesión
// SIGUE bloqueada (Hyprland muestra una pantalla de error). Para salir:
// Ctrl+Alt+F3, `hyprctl --instance 0 keyword misc:allow_session_lock_restore 1`
// y relanzar Elaren: como LockedHint sigue en true, vuelve a bloquear y se
// desbloquea con la contraseña (ver README, "Bloqueo en Hyprland").
Scope {
    id: root

    // Mensaje para la persona: error de contraseña, aviso de PAM…
    property string message: ""
    property bool messageIsError: false
    readonly property bool authenticating: pam.active && !awaitingResponse

    // PAM puede preguntar más de una cosa (código de un solo uso, PIN de una
    // llave U2F…). La contraseña ya escrita responde solo la primera; para
    // las siguientes se muestra la pregunta y se espera otra entrada.
    property bool passwordSent: false
    property bool awaitingResponse: false

    // Despierta (tarjetas visibles) o en reposo (solo reloj y disco).
    // Compartido entre pantallas, como la contraseña: tocar una despierta todas.
    property bool awake: false
    // Música en la pantalla: la opción de Configuración y un reproductor.
    readonly property bool showMedia: Config.lockscreenShowMedia && Media.available

    function wake(): void {
        awake = true;
        idleTimer.restart();
    }

    function sleep(): void {
        awake = false;
        idleTimer.stop();
        SessionLock.password = "";
    }

    // A los 10 s sin actividad (y sin nada escrito) vuelve al reposo. Si en
    // ese momento hay texto o PAM está verificando, se vuelve a esperar:
    // si no, la pantalla quedaba despierta (y cava andando) para siempre.
    Timer {
        id: idleTimer
        interval: 10000
        onTriggered: {
            if (SessionLock.password === "" && !root.authenticating && !root.awaitingResponse) root.awake = false;
            else restart();
        }
    }

    // Al dormirse, el anillo se desvanece con la animación lenta: cava sigue
    // ese rato para que las barras no caigan de golpe durante el fundido.
    Timer {
        id: spectrumFade
        interval: Theme.userAnim.slow
    }
    onAwakeChanged: if (!awake) spectrumFade.restart()

    // El espectro (cava) corre solo con la pantalla despierta y música
    // sonando: en reposo el bloqueo no gasta en audio.
    Binding {
        target: Visualizer
        property: "lockActive"
        value: SessionLock.locked && (root.awake || spectrumFade.running) && root.showMedia && Media.playing
    }

    function submit(): void {
        if (awaitingResponse) {
            // Enter sin escribir: no mandar una respuesta vacía, que contaría
            // como intento fallido.
            if (SessionLock.password === "") return;
            awaitingResponse = false;
            message = "";
            pam.respond(SessionLock.password);
            SessionLock.password = "";
            return;
        }
        if (pam.active || SessionLock.password === "") return;
        message = "";
        passwordSent = false;
        pam.start();
    }

    WlSessionLock {
        id: lock
        locked: SessionLock.locked

        // Si el compositor rechaza o termina el bloqueo, WlSessionLock vuelve
        // solo a `false`: hay que avisarle al servicio para no dejar el telón
        // de Power puesto sin forma de desbloquear.
        onLockedChanged: {
            console.info("sessionlock: WlSessionLock.locked =", locked);
            if (!locked && SessionLock.locked) SessionLock.fail();
        }
        onSecureChanged: {
            console.info("sessionlock: el compositor confirmó el bloqueo =", secure);
            SessionLock.secure = secure;
        }

        WlSessionLockSurface {
            Component.onCompleted: console.info("sessionlock: superficie creada en", screen?.name ?? "?")

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    // Usa /etc/pam.d/login, como el inicio de sesión en una TTY.
    PamContext {
        id: pam

        onPamMessage: {
            if (responseRequired && !root.passwordSent) {
                root.passwordSent = true;
                respond(SessionLock.password);
                SessionLock.password = "";
            } else if (responseRequired) {
                root.message = message;
                root.messageIsError = false;
                root.awaitingResponse = true;
            } else if (message !== "") {
                root.message = message;
                root.messageIsError = messageIsError;
            }
        }

        onCompleted: result => {
            root.awaitingResponse = false;
            if (result === PamResult.Success) {
                root.message = "";
                SessionLock.unlock();
                return;
            }
            SessionLock.password = "";
            if (root.awake) idleTimer.restart();
            root.messageIsError = true;
            root.message = result === PamResult.MaxTries ? "Demasiados intentos. Esperá un momento."
                : result === PamResult.Failed ? "Contraseña incorrecta"
                : "No se pudo verificar la contraseña";
        }

        onError: error => {
            root.awaitingResponse = false;
            SessionLock.password = "";
            if (root.awake) idleTimer.restart();
            root.messageIsError = true;
            root.message = "No se pudo verificar la contraseña";
            console.warn("sessionlock: error de PAM", PamError.toString(error));
        }
    }

    Connections {
        target: SessionLock
        function onLockedChanged(): void {
            // Asignación explícita: si el compositor soltó el bloqueo, la
            // vinculación de arriba ya no alcanza para volver a pedirlo.
            lock.locked = SessionLock.locked;
            root.awake = false;
            if (SessionLock.locked) {
                root.message = "";
                if (!lock.secure) confirmTimeout.restart();
            } else {
                confirmTimeout.stop();
                root.awaitingResponse = false;
                if (pam.active) pam.abort();
            }
        }
    }

    // Sin confirmación del compositor en unos segundos NO se desbloquea:
    // eso abría la sesión sola. Se sigue bloqueada (la contraseña desbloquea
    // igual) y solo se avisa en el registro. Rendirse queda para cuando el
    // compositor rechaza el bloqueo de forma explícita (onLockedChanged).
    Timer {
        id: confirmTimeout
        interval: 5000
        onTriggered: if (SessionLock.locked && !lock.secure)
            console.warn("sessionlock: 5 s sin confirmación del compositor; sigo bloqueada. locked =", lock.locked);
    }

    Component.onCompleted: {
        // Tras una recarga el bloqueo puede volver ya confirmado, sin
        // emitir secureChanged.
        SessionLock.secure = lock.secure;
        SessionLock.available = true;
        console.info("sessionlock: pantalla de bloqueo cargada");
    }
    Component.onDestruction: SessionLock.available = false
}
