# Propuesta: modo gaming

**Estado:** beta, no disponible. En la barra hay un botón (`modules/bar/GameModeButton.qml`)
visible pero deshabilitado. Este documento junta las alternativas para decidir
cómo implementarlo.

## Objetivo

Mientras se juega, Elaren tiene que gastar lo mínimo: apagar lo que consume
CPU, GPU o tiempo de composición, sin perder lo esencial (hora, batería,
volumen, red), y volver todo a como estaba al desactivar el modo.

## Qué consume hoy (de más a menos)

| Pieza | Por qué cuesta | Qué haría el modo gaming |
|-------|----------------|---------------------------|
| Visualizador de escritorio (`AudioVisualizer`) | Proceso `cava` + dibujo a ~60 fps a pantalla completa | Descargar su `LazyLoader` |
| Fondo propio (`Background`, skwd con videos/escenas) | Decodificar video y componer una capa a pantalla completa | Pausar o pasar a imagen fija |
| Desenfoque de KWin (`BackgroundEffect.blurRegion`) | KWin re-desenfoca detrás de barra/dock/popups en cada cuadro que cambia lo de abajo; con un juego eso es siempre | Vaciar las regiones de blur y subir la opacidad del vidrio |
| Widgets de escritorio (`DesktopWidgets`) | Una capa con varias vistas, relojes por segundo, gráficos | Desactivar sus `Loader` |
| Animaciones (`Theme.anim.scale`) | Redibujos de la barra y el dock | Forzar escala 0 |
| Dock | Otra capa siempre presente | Ocultarlo (o forzar autoocultar) |
| `SystemStats` | 4 lecturas de `/proc` cada 2 s | Bajar a 10 s o pausar |
| Isla abierta (visualizador, letras) | Ya se apaga sola al cerrarla | Nada |

## Alternativas

### A. Interruptor manual (recomendada para empezar)

Un servicio `services/GameMode.qml` con `property bool active` (estado de la
sesión, no persistente) que se prende desde el botón de la barra y por IPC
(`qs ipc call gamemode toggle`, para asignarle un atajo en KDE). Cada pieza de
la tabla se ata a `!GameMode.active`.

- **A favor:** simple, predecible, sin dependencias nuevas. Se puede probar de a
  una pieza.
- **En contra:** hay que acordarse de activarlo y de apagarlo.

### B. Automático con Feral GameMode

`gamemoded` (paquete `gamemode`) publica por DBus
`com.feralinteractive.GameMode` con la cantidad de juegos que lo pidieron
(`ClientCount`). Steam y Lutris lo usan con `gamemoderun %command%`. Elaren
escucharía esa propiedad y activaría el modo mientras sea mayor a 0.

- **A favor:** se activa y desactiva solo, con los juegos que ya usan GameMode,
  y además el propio `gamemoded` ajusta el gobernador de CPU.
- **En contra:** es una dependencia nueva (hoy no está instalado) y solo detecta
  juegos lanzados con `gamemoderun`.

### C. Automático por ventana a pantalla completa

Usar la integración con KWin (`services/KWin.qml` ya sigue la ventana activa)
para activar el modo cuando la ventana enfocada está a pantalla completa.

- **A favor:** sin dependencias; detecta cualquier juego.
- **En contra:** también se activaría con un video o una presentación a
  pantalla completa; habría que agregar una lista de apps excluidas. Necesita
  que el script de KWin informe el estado de pantalla completa.

### D. Híbrido (meta)

A como base, con B y/o C como disparadores opcionales en Configuración →
Barra ("Activar solo con GameMode", "Activar con pantalla completa"). El botón
siempre gana: si se apaga a mano, no se vuelve a prender hasta el próximo
juego.

## Recomendación

Implementar **A** primero (servicio + botón + IPC) apagando visualizador,
widgets, blur y animaciones, que son lo que más pesa. Después sumar **B** como
disparador opcional si se instala `gamemode`, y dejar **C** para más adelante.

## Pendiente de decidir

- Si el dock se oculta o se fuerza a autoocultar.
- Si el fondo se pausa o se reemplaza por una imagen fija.
- Si se muestra un aviso al activar/desactivar (notificación o un brillo en el
  botón de la barra).
