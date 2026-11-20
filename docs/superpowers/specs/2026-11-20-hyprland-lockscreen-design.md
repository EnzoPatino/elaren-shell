# Pantalla de bloqueo de Hyprland: rediseño "Dos mitades"

## Para qué

La pantalla de bloqueo propia de Elaren en Hyprland (`modules/lock/`) hoy es
el reloj digital grande y una tarjeta con avatar y contraseña, copia de la de
Plasma. Se busca una pantalla **original y minimalista** que además muestre
**música, clima, el usuario con su foto y un reloj analógico**. De paso se
corrigen los fallos del flujo de bloqueo que encontró el code review del
commit `d449c36`, porque un bloqueo lindo que se abre solo no sirve.

Prioridad declarada: que salga rápido. Entre los bocetos B (panel lateral) y
D (dos mitades), la persona eligió cualquiera de los dos; se toma **D**.

## Objetivos

- Distribución D: reloj analógico a la izquierda; a la derecha, tarjetas tipo
  bento: usuario (foto, nombre, contraseña, mensajes) arriba; música y clima
  abajo, lado a lado.
- Bloqueo que no falla abierto ni se duplica con hyprlock (ver "Flujo").

## No objetivos

- La pantalla de Plasma (`lockscreen/org.elaren.lockscreen/`): no se toca.
- Opciones nuevas en Configuración (se reutilizan `lockscreenBlur`,
  `lockscreenShowMedia` y `lockscreenClockSeconds`).
- Selector de wallpapers (queda para después).

## Anti-objetivos

- Que algo de la pantalla nueva saque el foco del campo de contraseña o deje
  de despertar la interfaz al escribir.
- Que el clima o la música hagan trabajo cuando no se pueden mostrar.

## Enfoques considerados

1. **Extraer el reloj analógico de `modules/desktop/ClockWidget.qml` a un
   componente (`components/AnalogClock.qml`) y armar las tarjetas del
   bloqueo leyendo directamente `Media`, `Weather` y `Avatar`.** Elegido:
   reutiliza el reloj que ya existe (con el "tic" del segundero) y deja una
   sola implementación para escritorio y bloqueo. Lo más rápido.
2. Meter los widgets de escritorio (`NowPlayingWidget`, `WeatherWidget`)
   dentro del bloqueo: arrastran `DesktopWidget` (posición guardada,
   arrastre, imán) que no tiene sentido acá. Descartado.
3. Dibujar todo de cero en `LockSurface.qml`: duplica el reloj. Descartado.

La persona delegó el cómo; la elección es mía.

## Diseño

**Reposo / despierto** (se conserva el comportamiento actual): en reposo
solo el reloj analógico, centrado y grande, con la fecha debajo. Al tocar una
tecla o el ratón, el reloj se desliza a la izquierda y achica un poco, y las
tarjetas entran desde la derecha (fundido + desplazamiento, con `Anim`). A los
10 s sin actividad y sin nada escrito, vuelve al reposo.

**Columna derecha** (tarjetas de vidrio con tokens de `Theme`):
- *Usuario*: `Avatar` con `Config.barAvatarShape`, nombre, campo de
  contraseña y mensaje de PAM, igual que hoy.
- *Música* (si `Config.lockscreenShowMedia` y `Media.available`): carátula,
  título, artista, barra de progreso y anterior / reproducir-pausa /
  siguiente. Sin reproductor no se crea (`Loader`).
- *Clima* (si hay `Weather.current`): icono, temperatura, descripción. Si no
  hay ciudad configurada no se muestra.
- Si falta una de las dos de abajo, la otra ocupa todo el ancho; si faltan
  ambas, queda solo la de usuario.

**Clima mientras está bloqueado**: `Weather.wanted` hoy depende de que el
widget de escritorio esté activo. Se amplía a "widget activo **o** sesión
bloqueada", siempre que haya ciudad.

**Estilo**: reemplazar los colores y tamaños fijos de `LockSurface.qml`
(`"black"`, `Qt.alpha("white", …)`, 112/22/15/14 px) por tokens de `Theme`.

## Flujo de bloqueo (hallazgos del review)

1. `Power.run("lock")` no vuelve a llamar `loginctl lock-session` (hacía
   que hypridle lanzara hyprlock en paralelo). Corregir el comentario
   `on_lock_cmd` → `lock_cmd`.
2. Si el compositor rechaza el bloqueo, ignorar señales `Lock` de logind por
   un momento para no reintentar en bucle.
3. La comprobación de `LockedHint` al arrancar corre aunque
   `logind-monitor.sh` no encuentre la sesión (con la ruta `auto`).
4. Si el compositor no confirma en 5 s, **no** desbloquear: reintentar y
   mantener el inhibidor de suspensión. `fail()` solo cuando el compositor
   rechaza explícitamente.
5. `readyToSleep = secure || !available || <falló el bloqueo durante la
   suspensión>`, en vez de `secure || !locked`.
6. Menores: pasar el motivo del desbloqueo en una señal en vez de
   `failed`; actualizar el comentario de `Power.qml` sobre quién desbloquea.

## Queda a criterio de quien lo construya

- Tamaños y proporciones exactos; monitores verticales (apilar en columna si
  el alto supera al ancho).
- Si el reloj del bloqueo usa la esfera con fondo o sin fondo.
- Detalles de la animación de entrada.

## Verificación

`./scripts/lint.sh` sin errores nuevos. Prueba manual en Hyprland:
`qs ipc … call power lock`, desbloquear con contraseña, con y sin
reproductor, con y sin ciudad, y suspender con la tapa.
