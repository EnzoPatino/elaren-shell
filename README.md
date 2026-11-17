# Elaren

<p align="center">
  <img src="branding/elaren.svg" alt="Logo de Elaren" width="210">
</p>

<p align="center"><strong>Una shell de escritorio para Wayland, hecha con Quickshell.</strong><br>
Compatible con <strong>KDE Plasma 6</strong> y <strong>Hyprland</strong>.</p>

Elaren reúne barra, lanzador, dock, widgets y controles del sistema en una
interfaz QML configurable, con animaciones y acento de color compartido. En
Plasma se integra con KWin; en Hyprland usa su backend nativo de Quickshell.

> **Estado:** proyecto en desarrollo activo, todavía sin paquete ni instalador.
> La instalación actual es desde el código fuente y está dirigida a personas
> familiarizadas con una sesión Wayland.

## Compatibilidad

| Entorno | Compatibilidad | Integración disponible |
|---|---|---|
| KDE Plasma 6 sobre Wayland | Compatible | Ventanas y escritorios de KWin, bandeja del sistema, fondo de Plasma y pantalla de bloqueo opcional para kscreenlocker |
| Hyprland | Compatible | Ventanas y escritorios mediante `Quickshell.Hyprland`, capturas con `grim`/`slurp` |
| X11 u otros compositores | No documentado ni verificado | No se ofrece soporte por ahora |

Elaren es una shell complementaria ejecutada por Quickshell: no reemplaza
`plasmashell` ni configura Hyprland por vos. En Plasma, el escritorio y sus
servicios siguen siendo de Plasma; podés ejecutar Elaren junto a ellos.

## Requisitos

- Una sesión Wayland en KDE Plasma 6 o Hyprland.
- [Quickshell](https://quickshell.org) con Qt 6 y los módulos que usa el
  proyecto; para Hyprland, una compilación que incluya `Quickshell.Hyprland`.
- Python 3 y Bash.
- La fuente **Material Symbols Rounded** para los iconos.

Para la integración completa con KWin también se necesita `python3-gi` y un
bus de sesión D-Bus funcional. Las funciones opcionales pueden requerir:

| Función | Dependencia opcional |
|---|---|
| Espectro de audio preciso | `cava` (sin él se usa el nivel de audio de PipeWire) |
| Modo gaming automático por juego | Feral GameMode (`gamemode`) |
| Capturas en Hyprland | `grim`; `slurp` para seleccionar una región; `wl-copy` y `notify-send` para extras |
| Pantalla de bloqueo de Elaren | KDE Plasma 6, `kscreenlocker` y `systemd --user` |
| Clima y letras | Conexión a internet cuando se consultan |

## Inicio rápido

Cloná el proyecto en una ruta permanente, instalá Quickshell y las dependencias
que quieras usar. Desde el directorio del proyecto, ejecutá:

```bash
./scripts/run.sh
```

El comando corre en primer plano y recarga la shell al guardar archivos. Para
cerrarla, usá `Ctrl+C`. Para iniciarla automáticamente en cada sesión, agregá
`scripts/run.sh` a las aplicaciones de inicio de tu entorno; no hay todavía un
instalador que configure ese paso.

En KDE Plasma, la pantalla de bloqueo se activa por separado desde
Configuración → Bloqueo o con `scripts/lockscreen.sh install`; sus detalles y
desinstalación están en la sección [Pantalla de bloqueo](#pantalla-de-bloqueo).

## Contenido

- [Desarrollo](#desarrollo)
- [Barra e isla](#la-barra)
- [Lanzador, dock y escritorio](#lanzador-de-aplicaciones)
- [Reproductor y visualizador](#reproductor)
- [Modo gaming](#modo-gaming)
- [Configuración](#configuración)
- [Bloqueo y energía](#bloquear-y-apagar)
- [Integración con el compositor](#integración-con-el-compositor)
- [Estructura del proyecto](#estructura)
- [Licencia y contribuciones](#licencia-y-contribuciones)

## Desarrollo

```bash
./scripts/run.sh    # arranca la shell; se recarga sola al guardar
./scripts/lint.sh   # qmllint sobre todos los .qml
```

`ELAREN_ANIM_SCALE` ajusta la velocidad de las animaciones
(`0` las desactiva, `2` las hace el doble de lentas):

```bash
ELAREN_ANIM_SCALE=2 ./scripts/run.sh
```

## La barra

Una franja de vidrio centrada que mide lo que su contenido, en el borde que
elijas (arriba, abajo o a un costado). En Configuración → Barra superior podés
elegir que lo que quede en el medio sea el avatar con el reloj en vez de la
barra entera.

| Zona      | Módulo                | Interacción                                              |
|-----------|-----------------------|----------------------------------------------------------|
| Izquierda | Apps                  | Clic: abre el lanzador de aplicaciones                   |
|           | Ventana activa        | Icono y título de la ventana enfocada                    |
|           | Escritorios virtuales | Clic: cambiar · Rueda: siguiente/anterior                |
| Centro    | Avatar y reloj        | Clic: despliega la isla                                  |
| Derecha   | Volumen y batería     | Rueda: ±5 % · Clic en icono: silenciar · Arrastrar: fijar|

## La isla

Clic en el avatar o el reloj: la isla crece desde la barra como una sola forma
de vidrio. Arriba tiene pestañas:

- **Inicio**: el avatar y el reloj en grande, con saludo y fecha.
- **Música** y **Letra**: el reproductor (solo si hay uno activo). La música ya
  no tiene widget propio en la barra: vive acá.
- **Recursos**: gráficos de CPU, memoria y red, GPU, swap, sensores y tiempo
  encendido.
- **Bandeja**: las apps de la bandeja del sistema. Clic: activar · Derecho: menú
  · Medio: acción secundaria.
- **Calendario**: rueda para cambiar de mes, clic en un día para ver cuánto falta.

Se cierra con un clic afuera, con Escape, con la flecha de la isla o volviendo a
tocar el avatar. Abierta no empuja las ventanas. El avatar puede ser un personaje
dibujado por la shell (generado a partir de una semilla, con ojos que siguen al
cursor y parpadean; "Mezclar" propone otros), uno de la galería que trae Plasma
(Konqi y compañía, en `/usr/share/plasma/avatars`) o tu foto de `~/.face`; su forma (círculo,
squircle, flor o hexágono) se elige en Configuración → Barra superior. Ahí
también se puede ocultar el avatar, hacer que no siga al cursor, que la isla
recuerde la última pestaña y elegir qué pestañas mostrar.

El botón con el joystick prende el **modo gaming** (clic derecho: sus ajustes).

## Modo gaming

Mientras está activo, Elaren gasta lo mínimo para dejarle la GPU al juego:
descarga el visualizador y los widgets de escritorio, apaga el desenfoque de
KWin (el vidrio pasa a ser casi opaco) y las animaciones, oculta el dock y lee
las métricas del sistema cada 10 s. Opcionalmente evita que la pantalla se
apague o se bloquee. Al apagarlo todo vuelve a como estaba; el estado no se
guarda entre sesiones.

Se prende con el botón de la barra, con un atajo de KDE o, en Configuración →
Modo gaming, solo mientras un juego use [Feral GameMode](https://github.com/FeralInteractive/gamemode)
(`gamemoderun %command%` en las opciones de lanzamiento de Steam; requiere el
paquete `gamemode`). Si lo apagás a mano durante un juego, no vuelve a
prenderse hasta el próximo.

```bash
qs ipc -p ~/proyectos/elaren-shell/shell.qml call gamemode toggle   # enable, disable, status
```

## Reproductor

Pestaña Música de la isla: vinilo (clic = pausa,
rueda = ±5 s), progreso, controles, volumen y selector de reproductor. El botón
de arriba a la derecha cambia al **modo letra**: solo el disco, el visualizador
y la letra sincronizada (clic en una línea para saltar a ese momento).

- Letras: [LRCLIB](https://lrclib.net) vía `scripts/lyrics.py`, con caché en
  `~/.cache/elaren/lyrics`. Solo se consulta con el modo letra abierto.
- Visualizador: usa [cava](https://github.com/karlstav/cava) si está instalado
  (`sudo apt install cava`); si no, barras moduladas por el nivel de audio real
  de PipeWire.

## Configuración

Panel propio de Elaren: engranaje en el lanzador, **clic derecho en el botón
"Apps"** de la barra, o `qs ipc -p ~/proyectos/elaren-shell/shell.qml call settings toggle`
(también `call settings openPage visualizer`). Secciones: Visualizador,
Apariencia (color de acento, velocidad de animaciones), Barra superior, Dock,
Fondo y Acerca de. Los cambios se aplican al instante y se guardan en
`~/.config/elaren/settings.json` (editable a mano; se recarga solo).

## Widgets de escritorio

Sobre el fondo y debajo de las ventanas (Configuración → Widgets):

- **Reloj**: digital (dígitos que ruedan, segundos opcionales), analógico
  (segundero con "tic" elástico) o en palabras ("Son las diez y cuarto").
- **Saludo**: buenos días / tardes / noches, con clima y tema que suena.
- **Música**: portada, progreso, controles y mini-espectro (solo con un
  reproductor abierto).
- **Monitor del sistema**: CPU, memoria, temperatura, red y tiempo encendido.
- **Clima**: actual y 3 días, vía [Open-Meteo](https://open-meteo.com) para la
  ciudad que configures (solo se envía el nombre de la ciudad).

Se arrastran con el ratón para acomodarlos (la posición se guarda); se pueden
bloquear, escalar y mostrar con o sin tarjeta de vidrio. En "Barra superior"
también se puede ocultar cada módulo, incluidos cafeína, red, brillo, volumen
y batería.

## Visualizador de escritorio

Mientras suena música aparecen sobre el fondo (debajo de las ventanas, sin
capturar clics) barras estilo cava o una onda, con el color de la portada.
Estilos: `bars`, `blocks`, `wave`, `mirror`, `line`; color de la portada, del
tema o arcoíris; altura, opacidad, cantidad y grosor de barras, sensibilidad y
tapitas. Todo desde Configuración → Visualizador, o por IPC:

```bash
qs ipc -p ~/proyectos/elaren-shell/shell.qml call visualizer cycle
qs ipc -p ~/proyectos/elaren-shell/shell.qml call visualizer setStyle wave
```

Con cava instalado muestra el espectro real; sin cava, barras moduladas por el
nivel de audio real de PipeWire.

**Ubicación**: va en cualquier lugar de la pantalla y las barras pueden crecer
hacia arriba, abajo, izquierda o derecha. En Configuración → Visualizador →
Ubicación hay atajos (abajo, arriba, a los costados, al centro), la dirección
y el largo; con **Mover** (o `call visualizer place`) se acomoda con el ratón:
arrastrar para moverlo (con imán a bordes y centro), rueda para el largo, clic
derecho para girarlo. Esc o "Listo" termina. Sin música muestra una demo
mientras tanto.

```bash
qs ipc -p ~/proyectos/elaren-shell/shell.qml call visualizer place
qs ipc -p ~/proyectos/elaren-shell/shell.qml call visualizer setDirection left
```

## Bloquear y apagar

Bloquear, suspender, cerrar sesión, reiniciar y apagar tienen una animación a
pantalla completa antes de ejecutarse (Esc o clic la cancelan mientras tanto):
el candado se cierra, la luna se mece, la mano saluda, la flecha gira o la
pantalla se apaga como un televisor de tubo. Al desbloquear la sesión (venga
el bloqueo de donde venga) la pantalla se abre en iris con un "Hola de nuevo".

Los botones del lanzador ya las usan. Para los atajos de KDE (Meta+L, botón de
encendido…), asigná en Atajos → Añadir comando:

```bash
qs ipc -p ~/proyectos/elaren-shell/shell.qml call power lock      # suspend, logout, reboot, poweroff
qs ipc -p ~/proyectos/elaren-shell/shell.qml call power preview poweroff   # solo la animación
```

### Pantalla de bloqueo

Elaren trae su propia pantalla de bloqueo (`lockscreen/org.elaren.lockscreen`):
reloj grande sobre el fondo desenfocado y, al tocar una tecla, una tarjeta de
vidrio con tu avatar, saludo y contraseña (los puntitos aparecen con rebote y
la tarjeta se sacude si te equivocás), controles de música, suspender, cambiar
de usuario, distribución de teclado y batería. Usa el acento y la forma del
avatar de Elaren.

KWin no implementa `ext-session-lock`, así que el bloqueo lo sigue haciendo
kscreenlocker (el de KDE): Elaren solo reemplaza su interfaz y la
autenticación, la protección de la sesión y las varias pantallas son las de
Plasma. Se activa en Configuración → Bloqueo (o con `scripts/lockscreen.sh
install`) y rige desde el **próximo inicio de sesión**: define
`PLASMA_DEFAULT_SHELL` solo para KWin con un drop-in en
`~/.config/systemd/user/plasma-kwin_wayland.service.d/`, sin tocar plasmashell.
Antes de activarla podés probarla con "Probar" (no bloquea; se cierra con tu
contraseña) o `scripts/lockscreen.sh test`.

Si alguna vez quedara trabada: Ctrl+Alt+F3, iniciá sesión y
`loginctl unlock-session`; `scripts/lockscreen.sh uninstall` vuelve a la de
Plasma.

## Lanzador de aplicaciones

Panel a pantalla completa con buscador, secciones (Todas, Frecuentes, Juegos,
Internet, Multimedia, Gráficos, Desarrollo, Oficina, Sistema, Utilidades) y
botones de bloquear / salir / reiniciar / apagar (los tres últimos piden
confirmación con un segundo clic).

- Escribí para buscar (nombre, descripción, palabras clave, o letras sueltas
  en orden: "ffx" → Firefox). Las apps que más abrís suben en el ranking.
- Flechas para moverse, Enter abre, Tab / Shift+Tab cambia de sección,
  Esc borra la búsqueda o cierra.
- Para abrirlo con un atajo, en Preferencias del sistema → Atajos → Añadir
  comando, usá:
  `qs ipc -p ~/proyectos/elaren-shell/shell.qml call launcher toggle`

Los iconos se resuelven a archivos con `scripts/icon-resolver.py` según el tema
de iconos de KDE (el proveedor `image://icon` de Quickshell dejaba iconos
invisibles en algunas ventanas).

## Fondo y dock

- **Fondo**: Elaren dibuja el wallpaper (sin `plasmashell` nadie lo hace).
  Usa el que tengas configurado en Plasma y lo sigue si lo cambiás; se puede
  forzar otro con `ELAREN_WALLPAPER=/ruta/imagen.jpg`.
- **skwd-wall**: si su daemon (`skwd-walld`) está activo, `scripts/run.sh` lo
  pasa a modo standalone (`SKWD_PLASMA_BACKEND=0`) mientras Elaren corre, así
  dibuja el fondo con skwd-paper (videos, escenas de Wallpaper Engine) en vez
  de mandarlo al plugin de Plasma, que sin `plasmashell` no existe. Elaren lo
  detecta y no dibuja su propio fondo. Al salir se restaura. Se controla con
  `ELAREN_SKWD_STANDALONE=0` y `ELAREN_WALLPAPER_PROVIDER=auto|elaren|skwd`.
- **Dock**: apps fijadas + apps abiertas. Clic abre / alterna / rota entre
  ventanas; clic medio abre otra instancia. Se esconde solo y aparece al tocar
  el borde inferior o si el escritorio está vacío.

Las preferencias (apps fijadas, autoocultar, tamaño de iconos, paralaje) están
en `config/Config.qml`.

## Integración con el compositor

Elaren detecta el compositor de la sesión y carga el backend correspondiente.

### KWin en Plasma

KWin no ofrece la lista de ventanas ni los escritorios por protocolos Wayland
que Quickshell entienda (`ext-workspace`, `foreign-toplevel`). Por eso
`scripts/kwin-bridge.py` carga un script en KWin (`kwin/bridge.js`) que envía
el estado por D-Bus, y Elaren lo lee de la salida del helper. Las órdenes
(activar, minimizar, cambiar de escritorio) se ejecutan como scripts de KWin
de un solo uso. Requiere `python3-gi`.

#### Capturas de pantalla

Mientras Spectacle muestra su selector, los popups de la barra (reproductor,
calendario, sistema) se ocultan al instante: si no, KWin los pinta por encima
del selector. Como Spectacle congela la pantalla antes de mostrar el selector,
para que el popup tampoco salga en la foto conviene lanzar la captura desde
Elaren, que primero cierra los popups y después abre Spectacle. En
Configuración del sistema → Atajos, asigná a Impr Pant un comando como:

```sh
qs ipc -p ~/proyectos/elaren-shell/shell.qml call screenshot region
```

(también `fullscreen`, `window` y `monitor`), y quitale ese atajo a Spectacle.

### Hyprland

Las ventanas, escritorios y acciones del dock se conectan al módulo
`Quickshell.Hyprland`. Hyprland no ofrece minimización tradicional: Elaren la
simula moviendo ventanas al espacio especial `special:minimized`. La cantidad
base de escritorios visibles se ajusta en Configuración → Barra superior.

Las capturas usan `grim` y, para una región, `slurp`; se guardan en
`$XDG_PICTURES_DIR/Capturas` (o `~/Imágenes/Capturas`).

> La pantalla de bloqueo incluida usa kscreenlocker y está pensada para KDE
> Plasma; no reemplaza el bloqueo de Hyprland.

## Animaciones

- **Entrada**: la barra cae desde arriba con rebote y los grupos aparecen
  escalonados (también en cada recarga en caliente).
- **Escritorios**: el indicador se desplaza con efecto "gusano".
  Rótulos a elección (Configuración → Barra superior): números, romanos
  (I II III), kanji (一 二 三), solo puntos o **Pac-Man** (el activo es un
  pacman que viaja comiendo al cambiar de escritorio, los que tienen ventanas
  son fantasmas que lo siguen con la mirada y los vacíos, pellets; idea del
  estilo "Caelestia" de [neko-desktops](https://github.com/ezku100/neko-desktops),
  dibujado desde cero). Al cambiar de estilo giran en cascada.
- **Reloj**: los dígitos ruedan como un marcador mecánico.
- **Calendario**: se despliega con rebote, desliza la cuadrícula al cambiar de
  mes y se cierra al sacar el ratón.
- **Volumen**: el deslizador aparece al pasar el ratón o al cambiar el volumen.
- **Batería**: "late" al enchufar el cargador y avisa cuando está crítica.
- **Fondo**: zoom-out al arrancar, fundido al cambiar de imagen y paralaje
  al cambiar de escritorio.
- **Dock**: sube con rebote, magnificación estilo macOS, iconos que entran
  escalonados, rebote al abrir una app e indicadores animados de ventanas.
- **Botones**: hover suave y onda (ripple) desde el punto de clic.

## Estructura

- `shell.qml` — punto de entrada
- `config/` — preferencias de usuario (singleton `Config`)
- `modules/` — piezas visibles (fondo, barra, calendario, dock)
- `services/` — lógica sin UI: hora, audio (PipeWire), batería (UPower),
  multimedia (MPRIS), ventanas y escritorios (KWin), apps, wallpaper
- `kwin/` y `scripts/kwin-bridge.py` — puente con KWin
- `services/backends/` — integración específica por compositor (Hyprland)
- `lockscreen/` y `scripts/lockscreen.sh` — pantalla de bloqueo (paquete
  para kscreenlocker, no corre dentro de Quickshell)
- `branding/` — identidad visual de Elaren
- `components/` — controles reutilizables y animaciones base
  (`Anim`, `CAnim`, `StateLayer`, `Reveal`, `RollingText`, `MaterialIcon`…)
- `theme/` — colores, tipografía, formas y curvas de movimiento (singleton `Theme`)

## Licencia y contribuciones

El repositorio todavía no incluye un archivo de licencia en la raíz. Antes de
publicar una versión distribuible, definí la licencia del proyecto y agregá el
archivo correspondiente. La pantalla de bloqueo declara GPL-2.0+ en sus
metadatos, pero eso no establece por sí solo la licencia del resto del repo.

Para reportar errores o proponer cambios, abrí un issue o pull request con el
compositor, la versión de Quickshell y los pasos para reproducir el problema.
