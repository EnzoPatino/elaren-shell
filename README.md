# Elaren

Shell de escritorio para **KDE Plasma 6** (Wayland) escrita en QML con
[Quickshell](https://quickshell.org).

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

| Zona      | Módulo                | Interacción                                              |
|-----------|-----------------------|----------------------------------------------------------|
| Izquierda | Apps                  | Clic: abre el lanzador de aplicaciones                   |
|           | Ventana activa        | Icono y título de la ventana enfocada                    |
|           | Escritorios virtuales | Clic: cambiar · Rueda: siguiente/anterior                |
| Centro    | Reloj                 | Clic: calendario (rueda: cambiar de mes)                 |
| Derecha   | Sistema               | Hover: red · Clic: panel con gráficos de CPU/RAM/red, GPU, swap |
|           | Multimedia (MPRIS)    | Hover: controles anterior / pausa / siguiente            |
|           | Bandeja del sistema   | Clic: activar · Derecho: menú · Medio: acción secundaria |
|           | Volumen y batería     | Rueda: ±5 % · Clic en icono: silenciar · Arrastrar: fijar|

## Reproductor

Clic en el widget de música de la barra: tarjeta con vinilo (clic = pausa,
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

## Integración con KWin

KWin no ofrece la lista de ventanas ni los escritorios por protocolos Wayland
que Quickshell entienda (`ext-workspace`, `foreign-toplevel`). Por eso
`scripts/kwin-bridge.py` carga un script en KWin (`kwin/bridge.js`) que envía
el estado por D-Bus, y Elaren lo lee de la salida del helper. Las órdenes
(activar, minimizar, cambiar de escritorio) se ejecutan como scripts de KWin
de un solo uso. Requiere `python3-gi`.

### Capturas de pantalla

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
- **Multimedia**: la carátula gira mientras suena; los controles se despliegan.
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
- `components/` — controles reutilizables y animaciones base
  (`Anim`, `CAnim`, `StateLayer`, `Reveal`, `RollingText`, `MaterialIcon`…)
- `theme/` — colores, tipografía, formas y curvas de movimiento (singleton `Theme`)

Requiere la fuente **Material Symbols Rounded** para los iconos.

## Guía local para agentes

En la raíz del proyecto puede existir un `AGENTS.md` con instrucciones de
desarrollo, mapa de módulos y notas sobre configuración y widgets. Es una guía
local ignorada por Git, así que no se incluye ni aparece en GitHub. Si falta,
consultá este README y los comentarios junto al código antes de cambiar una
pieza.
