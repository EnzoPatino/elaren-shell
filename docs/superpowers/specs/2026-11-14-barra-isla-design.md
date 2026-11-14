# Diseño: barra compacta con isla desplegable

**Fecha:** 2026-11-14 · **Estado:** para aprobar · **Base:** `docs/propuesta-barra-superior-expandible.md` y bocetos.

## Por qué

La barra actual ocupa todo el ancho y queda larga y vacía. Se busca una barra más
chica y con más vida: un avatar con forma y un reloj al centro que, al tocarlos,
despliegan una isla grande al estilo del dashboard de Caelestia, con el avatar, el
reloj en grande y accesos a la música (disco), la letra y el calendario.

## Objetivos

- La barra sigue siendo **una sola franja continua de vidrio**, pero mide lo que su
  contenido (centrada en el borde), sin espacios vacíos. Conserva sus grupos
  actuales: lanzador, workspaces, ventana activa, sistema, música, bandeja, iconos.
- En el centro, en lugar del `Clock` actual: **avatar + reloj** (la "isla compacta").
- Clic en avatar o reloj → la isla **crece desde la barra** como una sola forma de
  vidrio fusionada con ella.
- Dentro de la isla, pestañas: **Inicio** (avatar y reloj grandes, fecha),
  **Música** (vinilo, controles, visualizador), **Letra** (letra sincronizada),
  **Calendario**. Música y Letra solo aparecen si `Media.available`.
- Cierre: **clic en cualquier lugar fuera de la isla**, Escape, o volver a tocar
  avatar/reloj. Sacar el mouse **no** la cierra.
- Funciona con la barra arriba, abajo, izquierda y derecha.

## No objetivos (segunda etapa)

Notificaciones, "agregar acceso", reloj/temporizador con controles, "dibujo animado",
elegir otra imagen de avatar desde la interfaz.

## Anti-objetivos

- Que la isla abierta empuje o redimensione las ventanas (la reserva de espacio no
  cambia nunca).
- Que la capa transparente bloquee clics del escritorio con la isla cerrada.
- Que cava, letras o animaciones sigan trabajando con la isla cerrada.
- Duplicar la lógica de `NowPlayingPopup`/`CalendarPopup` en vez de reutilizarla.

## Enfoques considerados

- **A. Una ventana por pantalla, estilo Caelestia (elegido).** Barra e isla en la
  misma superficie transparente; el vidrio se dibuja como una forma única. Se ve
  fusionado de verdad y el clic afuera se resuelve en la misma ventana. Costo:
  reorganizar `Bar.qml`. La persona usuaria pidió la opción que más le convenga; se
  eligió esta por ser la única que logra la unión sin costuras.
- **B. Isla como popup aparte con "cuello" dibujado.** Menos cambios, pero la unión
  entre dos ventanas (desenfoque y animación) puede notarse.
- **C. Reutilizar `AnimatedPopup` tal cual.** Descartada: es una tarjeta separada,
  justo lo contrario del boceto.

## Cómo se construye (decidido)

### Ventanas

- `Bar.qml` pasa a ser una `PanelWindow` **anclada a los cuatro bordes**, transparente,
  `WlrLayershell.exclusionMode: ExclusionMode.Ignore`, capa `Top`.
- Una `PanelWindow` invisible aparte (`BarReserve`), anclada solo al borde elegido,
  con `exclusiveZone` igual al grosor de la barra: es la que reserva espacio para
  las ventanas. Con la isla abierta no cambia.
- **Máscara de entrada** (`mask: Region`):
  - isla cerrada → solo el rectángulo de la barra;
  - isla abierta → toda la pantalla, y una `MouseArea` de fondo cierra la isla con
    cualquier clic fuera de ella (ese clic solo cierra, no llega a la app de abajo,
    igual que un menú).
- Teclado: `WlrLayershell.keyboardFocus` en `Exclusive` mientras la isla está abierta
  (para Escape), `None` cerrada.
- Desenfoque: `BackgroundEffect.blurRegion` como unión de la región de la barra y la
  de la isla.
- Igual que `AnimatedPopup`, se cierra sin animación si `KWin.screenshotActive`.

### Barra compacta

- El ancho del fondo = ancho implícito del contenido + márgenes, centrado sobre el
  borde. Se anima el cambio de ancho (`Anim`). En laterales se mantiene la rotación
  actual de la composición.

### Avatar

- `components/Avatar.qml`: imagen de `~/.face` (en este equipo es un SVG; se carga
  con `sourceSize` adecuado). Sin archivo, ícono de persona con el acento del tema.
- Forma elegible, recortada con `MultiEffect` + máscara dibujada con `Shape`
  (renderer de curvas, **sin `asynchronous`**): `circle`, `squircle`, `flower`,
  `hexagon`.
- Animación chica: se inclina y desplaza unos píxeles hacia el cursor mientras el
  puntero está sobre la barra o la isla; vuelve al centro al salir. Respeta
  `ELAREN_ANIM_SCALE` (con escala 0 queda quieto).

### Isla

- Componente `modules/bar/Island.qml` dentro de la ventana de la barra, anclado al
  centro del contenido. Crece hacia el interior de la pantalla (abajo si la barra
  está arriba, arriba si está abajo, hacia el centro si está a un costado). Su
  contenido **no** va rotado.
- Forma: la barra y la isla se dibujan unidas con esquinas invertidas en la unión
  (como en Caelestia), usando los tokens `Theme.glass`, `Theme.glassBorder` y
  `Theme.radius.large`. Apertura con `Theme.anim.expressive`, cierre con
  `emphasizedAccel`, como `AnimatedPopup`.
- Pestañas en una fila arriba de la isla; cada vista en un `Loader` activo solo si
  la isla está abierta y esa pestaña está elegida.
- **Vistas reutilizadas**: se extrae el contenido de `NowPlayingPopup.qml` a
  `NowPlayingView.qml` (vista Música; su modo letra se convierte en la vista Letra) y
  el de `CalendarPopup.qml` a `CalendarView.qml`. Los bindings de
  `Visualizer.popupActive` y `Lyrics.wanted` pasan a las vistas. Los popups viejos
  de música y calendario se eliminan.
- Accesos: clic en avatar/reloj → abre en Inicio (o cierra si ya está abierta);
  clic en el `MediaWidget` → abre en Música.
- Solo una superficie abierta: abrir la isla cierra `activePopup` (sistema) y abrir
  el popup de sistema cierra la isla.

### Configuración

- Nueva preferencia `barAvatarShape` (`"circle" | "squircle" | "flower" |
  "hexagon"`, por defecto `"squircle"`), sincronizada en alias, `defaults` y
  `JsonAdapter store` de `config/Config.qml`.
- Control `ChoiceRow` "Forma del avatar" en Configuración → Barra.
- README: describir la isla y la forma del avatar.

### Incluido también

- Arreglo del cuelgue de Quickshell: se quitó `asynchronous: true` del `Shape` de
  `components/SpectrumView.qml` (segfault en QtQuickShapes con el visualizador en
  modo onda). Ya aplicado.

## Para quien construya (decisiones menores)

- Medidas exactas de la isla (ancho ~620 px para Música, como el popup actual) y
  alto por vista.
- Comprobar que los menús de la bandeja (`Tray` usa `barWindow`) y el
  `SystemPopup` siguen anclando bien con la ventana a pantalla completa.
- En vertical, alinear la isla al reloj y limitarla para que no se salga de la
  pantalla.
- Validación: `./scripts/lint.sh` sobre los archivos tocados y prueba manual con
  `./scripts/run.sh` en las cuatro posiciones. Sin commit ni push.
