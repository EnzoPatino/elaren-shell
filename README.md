# Elaren

<p align="center">
  <img src="branding/elaren.svg" alt="Logo de Elaren" width="210">
</p>

<p align="center"><strong>Una shell de escritorio para Wayland, hecha con Quickshell.</strong><br>
Funciona en <strong>KDE Plasma 6</strong> y en <strong>Hyprland</strong>.</p>

Elaren junta barra, isla desplegable, lanzador, dock, widgets de escritorio,
visualizador de música y pantalla de bloqueo en una sola interfaz QML con
vidrio, animaciones y un color de acento compartido. En Plasma se integra con
KWin; en Hyprland usa el backend nativo de Quickshell.

> **Estado:** primera versión pública. Se instala desde el código fuente (todavía
> no hay paquetes) y está pensada para personas que ya usan una sesión Wayland.

## Contenido

- [Elaren en acción](#elaren-en-acción)
- [Qué trae](#qué-trae)
- [Compatibilidad](#compatibilidad)
- [Requisitos](#requisitos)
  - [Instalar las dependencias](#instalar-las-dependencias)
- [Instalación](#instalación)
  - [KDE Plasma 6](#kde-plasma-6)
  - [Hyprland](#hyprland)
  - [Actualizar y desinstalar](#actualizar-y-desinstalar)
  - [Instalación con un agente de IA](#instalación-con-un-agente-de-ia)
- [Uso](#uso)
- [Bloqueo y energía](#bloqueo-y-energía)
- [Atajos y comandos IPC](#atajos-y-comandos-ipc)
- [Solución de problemas](#solución-de-problemas)
- [Cómo funciona por dentro](#cómo-funciona-por-dentro)
- [Desarrollo](#desarrollo)
- [Licencia y contribuciones](#licencia-y-contribuciones)

## Elaren en acción

### En KDE Plasma 6

https://github.com/user-attachments/assets/0aace2cf-c530-4b82-ad25-3599179a845b

_Barra, isla, widgets y ajustes (2:28)._

### En Hyprland

https://github.com/user-attachments/assets/cc614bc4-d27b-4fdf-a18b-148be8bb7fef

_Isla, visualizador, fondos y bloqueo de sesión (2:00)._

## Qué trae

- **Barra e isla**: una franja de vidrio que crece hasta ser una isla con
  inicio, música, letra sincronizada, recursos del sistema, bandeja y
  calendario.
- **Lanzador** a pantalla completa con búsqueda difusa, secciones y ranking
  de apps frecuentes.
- **Dock** con apps fijadas y abiertas, magnificación y autoocultado.
- **Widgets de escritorio**: reloj, saludo, música, monitor del sistema y
  clima; se arrastran y se guardan donde los dejás.
- **Visualizador** de audio sobre el fondo, con el color de la portada.
- **Modo gaming**: apaga lo que gasta GPU mientras jugás, a mano o
  automáticamente con GameMode.
- **Bloqueo y energía** con animaciones propias y pantalla de bloqueo de
  Elaren en los dos escritorios.
- **Panel de configuración** propio: todo se aplica al instante.

## Compatibilidad

| Entorno | Estado | Integración |
|---|---|---|
| KDE Plasma 6 (Wayland) | Compatible | Ventanas y escritorios de KWin, bandeja del sistema, fondo de Plasma, capturas con Spectacle y pantalla de bloqueo opcional para kscreenlocker |
| Hyprland | Compatible | Ventanas y escritorios mediante `Quickshell.Hyprland`, capturas con `grim`/`slurp` y bloqueo de sesión propio (`ext-session-lock` y PAM) |
| X11 u otros compositores | No soportado | — |

Elaren es una shell complementaria: no reemplaza `plasmashell` ni configura
Hyprland por vos. En Plasma podés correrla junto al escritorio de siempre.

## Requisitos

- Una sesión Wayland en KDE Plasma 6 o Hyprland.
- [Quickshell](https://quickshell.org) con Qt 6. Para Hyprland, una compilación
  que incluya `Quickshell.Hyprland` y los módulos de PAM y bloqueo de sesión.
- Git, Python 3 y Bash.
- La fuente **Material Symbols Rounded** para los iconos.
- En Plasma: `python3-gi` y un bus de sesión D-Bus (integración con KWin).

Opcionales:

| Función | Dependencia |
|---|---|
| Espectro de audio preciso | `cava` (sin él se usa el nivel de audio de PipeWire) |
| Modo gaming automático por juego | Feral GameMode (`gamemode`) |
| Botón de Bluetooth | `bluez` con el servicio `bluetooth` activo (Plasma ya lo trae) |
| Botón de perfil de energía | `power-profiles-daemon` o `tuned-ppd` (Plasma ya trae uno de los dos) |
| Capturas en Hyprland | `grim`; `slurp` para regiones; `wl-copy` y `notify-send` para copiar y avisar |
| Bloqueo en Hyprland | `busctl`, `gdbus` y `systemd-inhibit` |
| Pantalla de bloqueo en Plasma | `kscreenlocker` y `systemd --user` |
| Clima y letras | Conexión a internet al consultarlos |

### Instalar las dependencias

Nombres de paquetes habituales (pueden cambiar según la versión de la
distribución; buscalos en tu gestor si alguno no aparece):

| Distribución | Comando |
|---|---|
| Debian, Ubuntu, PikaOS | `sudo apt install quickshell git python3 python3-gi` |
| Arch y derivadas | `sudo pacman -S git python python-gobject` y `quickshell` (o `quickshell-git` del AUR) |
| Fedora | `sudo dnf install git python3 python3-gobject` y Quickshell desde un repositorio COPR |

Si tu distribución no empaqueta Quickshell, seguí las instrucciones de
<https://quickshell.org>. `python3-gi` (o su equivalente) solo hace falta en
Plasma.

**Fuente de iconos.** Sin Material Symbols Rounded los iconos se ven como
texto. Si `fc-list | grep -i "material symbols"` no lista nada, instalala solo
para tu usuario:

```bash
mkdir -p ~/.local/share/fonts
curl -fL -o ~/.local/share/fonts/MaterialSymbolsRounded.ttf \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
```

Los opcionales de la tabla anterior se instalan con el mismo gestor (por
ejemplo `cava`, `gamemode`, `grim`, `slurp`), solo si querés esa función.

## Instalación

Cloná el repo en una ruta **permanente** (el autoarranque, los atajos y la
pantalla de bloqueo apuntan ahí). En esta guía, `<ruta>` es esa ruta absoluta.

```bash
git clone https://github.com/EnzoPatino/elaren-shell.git <ruta>
cd <ruta>
./scripts/run.sh
```

`run.sh` corre en primer plano y recarga la shell al guardar archivos;
`Ctrl+C` la cierra. Si la barra aparece, ya está andando: falta que arranque
sola en cada sesión.

### KDE Plasma 6

1. **Arranque automático.** Agregá `<ruta>/scripts/run.sh` en Configuración
   del sistema → Autoarranque, o creá `~/.config/autostart/elaren.desktop`:

   ```ini
   [Desktop Entry]
   Type=Application
   Name=Elaren
   Exec=<ruta>/scripts/run.sh
   Icon=quickshell
   Terminal=false
   X-KDE-autostart-after=panel
   X-KDE-autostart-phase=2
   OnlyShowIn=KDE;
   ```

2. **Atajos** (opcional). En Configuración del sistema → Atajos → Añadir
   comando, asigná los comandos de [Atajos y comandos IPC](#atajos-y-comandos-ipc):
   lanzador, bloqueo con animación y capturas (quitale Impr Pant a Spectacle).

3. **Pantalla de bloqueo** (opcional). Configuración → Bloqueo en Elaren, o
   `./scripts/lockscreen.sh install`. Rige desde el próximo inicio de sesión;
   detalles en [Pantalla de bloqueo en Plasma](#pantalla-de-bloqueo-en-plasma).

Si usás Krohnkite, `run.sh` lo ajusta solo para que no acomode la barra ni
los widgets como si fueran ventanas.

### Hyprland

Agregá a `~/.config/hypr/hyprland.conf` (hacé una copia antes):

```ini
exec-once = <ruta>/scripts/run.sh

misc {
    allow_session_lock_restore = true
}

# Teclas de volumen y brillo: pasan por Elaren, que muestra el deslizador.
$elaren = qs ipc -p <ruta>/shell.qml call
bindel = , XF86AudioRaiseVolume, exec, $elaren volume up
bindel = , XF86AudioLowerVolume, exec, $elaren volume down
bindl  = , XF86AudioMute, exec, $elaren volume mute
bindel = , XF86MonBrightnessUp, exec, $elaren brightness up
bindel = , XF86MonBrightnessDown, exec, $elaren brightness down

# Opcionales
bind = SUPER, SPACE, exec, $elaren launcher toggle
bind = SUPER, L, exec, $elaren power lock
bind = , Print, exec, $elaren screenshot region
```

- Si ya tenés un bloque `misc { … }`, poné la línea adentro de ese.
- Si ya hay `bind` de esas teclas con `wpctl` o `brightnessctl`, sacalos: si
  no, cada tecla actúa dos veces.
- Sin PowerDevil (lo normal en Hyprland), el brillo se lee de
  `/sys/class/backlight` y se cambia con logind: no hace falta `brightnessctl`
  ni permisos extra.
- No uses hyprlock al mismo tiempo. Si usás hypridle, mirá
  [Bloqueo en Hyprland](#bloqueo-en-hyprland).

Aplicalo con `hyprctl reload` o al volver a iniciar sesión.

### Actualizar y desinstalar

```bash
cd <ruta>
git pull --ff-only
```

Elaren se recarga sola al cambiar sus archivos. Si cambió `scripts/run.sh`,
reiniciala (cerrá sesión o relanzá `run.sh`); si cambió el bloque de
`hyprland.conf` de este README, aplicá la diferencia y corré `hyprctl reload`.

Para desinstalar:

1. En Plasma, si activaste la pantalla de bloqueo: `./scripts/lockscreen.sh uninstall`.
2. Sacá el autoarranque (`~/.config/autostart/elaren.desktop` o la línea
   `exec-once` y los `bind` de `hyprland.conf`) y los atajos que hayas creado.
3. Borrá `<ruta>`. Tus preferencias quedan en `~/.config/elaren/` y la caché
   de letras en `~/.cache/elaren/`, por si querés borrarlas también.

### Instalación con un agente de IA

[`docs/INSTALACION-AGENTES.md`](docs/INSTALACION-AGENTES.md) es un manual paso
a paso para que un agente (Claude Code, Codex, etc.) instale, verifique,
actualice o desinstale Elaren por vos, pidiendo permiso antes de usar `sudo`
o tocar tu configuración. Pasale al agente:

> Instalá Elaren siguiendo `docs/INSTALACION-AGENTES.md` de
> https://github.com/EnzoPatino/elaren-shell

## Uso

### La barra

Una franja de vidrio centrada que mide lo que su contenido, en el borde que
elijas (arriba, abajo o a un costado). En Configuración → Barra superior podés
dejar en el medio solo el avatar con el reloj y ocultar cada módulo.

| Zona | Módulo | Interacción |
|---|---|---|
| Izquierda | Apps | Clic: lanzador · Clic derecho: configuración |
| | Ventana activa | Icono y título de la ventana enfocada |
| | Escritorios virtuales | Clic: cambiar · Rueda: siguiente/anterior |
| Centro | Avatar y reloj | Clic: despliega la isla |
| Derecha | Cafeína, perfil de energía, red, Bluetooth, brillo, volumen y batería | Rueda: ±5 % · Clic en icono: silenciar · Arrastrar: fijar |
| | Perfil de energía | Clic: Ahorro → Equilibrado → Rendimiento · Clic derecho: energía de Plasma |
| | Bluetooth | Clic: prender/apagar · Clic derecho: dispositivos |
| | Modo gaming | Clic: prender/apagar · Clic derecho: sus ajustes |

### La isla

Clic en el avatar o el reloj y la isla crece desde la barra como una sola
forma de vidrio, con pestañas:

- **Inicio**: avatar y reloj en grande, con saludo y fecha.
- **Música** y **Letra**: el reproductor (solo con uno activo). Vinilo (clic =
  pausa, rueda = ±5 s), progreso, controles, volumen y selector de
  reproductor. La letra es sincronizada: clic en una línea para saltar ahí.
- **Recursos**: CPU, memoria, red, GPU, swap, sensores y tiempo encendido.
- **Bandeja**: apps de la bandeja del sistema. Clic: activar · Derecho: menú ·
  Medio: acción secundaria.
- **Calendario**: rueda para cambiar de mes, clic en un día para ver cuánto falta.

Se cierra con un clic afuera, Escape, la flecha de la isla o tocando otra vez
el avatar, y no empuja las ventanas. El avatar puede ser un personaje dibujado
por la shell (con ojos que siguen al cursor y parpadean; "Mezclar" propone
otros), uno de la galería de Plasma (`/usr/share/plasma/avatars`) o tu foto
de `~/.face`, con forma de círculo, squircle, flor o hexágono.

Las letras salen de [LRCLIB](https://lrclib.net) (con caché en
`~/.cache/elaren/lyrics`) y solo se consultan con la pestaña Letra abierta.

### Lanzador

Panel a pantalla completa con buscador, secciones (Todas, Frecuentes, Juegos,
Internet, Multimedia, Gráficos, Desarrollo, Oficina, Sistema, Utilidades) y
botones de bloquear, salir, reiniciar y apagar (los tres últimos piden un
segundo clic).

- Escribí para buscar por nombre, descripción, palabras clave o letras sueltas
  en orden ("ffx" → Firefox). Las apps que más abrís suben en el ranking.
- Flechas para moverse, Enter abre, Tab / Shift+Tab cambia de sección, Esc
  borra la búsqueda o cierra.

### Dock y fondo

- **Dock**: apps fijadas y abiertas. Clic abre, alterna o rota entre
  ventanas; clic medio abre otra instancia. Se esconde solo y aparece al tocar
  el borde inferior o con el escritorio vacío. Tamaño y comportamiento en
  Configuración → Dock.
- **Fondo**: en una sesión de Plasma normal el fondo lo sigue dibujando
  Plasma. Si `plasmashell` no está corriendo (o en Hyprland), lo dibuja
  Elaren, con el wallpaper configurado en Plasma o el de
  `ELAREN_WALLPAPER=/ruta/imagen.jpg`. Zoom al arrancar, fundido al cambiar y
  paralaje entre escritorios.
- **skwd-wall**: si su daemon (`skwd-walld`) está activo y no hay
  `plasmashell`, `run.sh` lo pasa a modo standalone mientras Elaren corre y lo
  restaura al salir. Se controla con `ELAREN_SKWD_STANDALONE=0` y
  `ELAREN_WALLPAPER_PROVIDER=auto|elaren|skwd`.

### Widgets de escritorio

Sobre el fondo y debajo de las ventanas (Configuración → Widgets):

- **Reloj**: digital (dígitos que ruedan), analógico (segundero elástico) o en
  palabras ("Son las diez y cuarto").
- **Saludo**: buenos días / tardes / noches, con clima y el tema que suena.
- **Música**: portada, progreso, controles y mini-espectro (solo con un
  reproductor abierto).
- **Monitor del sistema**: CPU, memoria, temperatura, red y tiempo encendido.
- **Clima**: actual y 3 días, vía [Open-Meteo](https://open-meteo.com) para la
  ciudad que configures (solo se envía el nombre de la ciudad).

Se arrastran para acomodarlos (con imán a bordes y centro) y la posición se
guarda; se pueden bloquear, escalar y mostrar con o sin tarjeta de vidrio.

### Visualizador

Mientras suena música aparecen sobre el fondo, sin capturar clics, barras o
una onda con el color de la portada. Estilos `bars`, `blocks`, `wave`,
`mirror` y `line`; color de la portada, del tema o arcoíris; altura,
opacidad, cantidad, grosor, sensibilidad y tapitas en Configuración →
Visualizador.

Va en cualquier lugar de la pantalla y puede crecer hacia cualquier lado. Con
**Mover** (o `call visualizer place`) se acomoda con el ratón: arrastrar para
moverlo, rueda para el largo, clic derecho para girarlo; Esc o "Listo"
termina. Con [cava](https://github.com/karlstav/cava) instalado muestra el
espectro real; sin él, barras moduladas por el nivel de audio de PipeWire.

### Modo gaming

Mientras está activo, Elaren gasta lo mínimo para dejarle la GPU al juego:
descarga el visualizador y los widgets, apaga el desenfoque de KWin (el vidrio
pasa a ser casi opaco) y las animaciones, oculta el dock y lee las métricas
cada 10 s. Opcionalmente evita que la pantalla se apague o se bloquee. Al
apagarlo todo vuelve a como estaba.

Se prende con el botón de la barra, con un atajo o, desde Configuración →
Modo gaming, solo mientras un juego use
[Feral GameMode](https://github.com/FeralInteractive/gamemode)
(`gamemoderun %command%` en las opciones de lanzamiento de Steam). Si lo
apagás a mano durante un juego, no vuelve a prenderse hasta el próximo.

### Configuración

Engranaje en el lanzador, **clic derecho en "Apps"** o
`call settings toggle`. Páginas: Visualizador, Widgets, Apariencia, Barra
superior, Dock, Fondo, Modo gaming, Bloqueo y Acerca de. Los cambios se
aplican al instante y se guardan en `~/.config/elaren/settings.json`
(editable a mano: se recarga solo).

### Animaciones

La barra cae con rebote al arrancar; el indicador de escritorios se desplaza
como un gusano y sus rótulos pueden ser números, romanos, kanji, puntos o
**Pac-Man** (idea del estilo "Caelestia" de
[neko-desktops](https://github.com/ezku100/neko-desktops), dibujado desde
cero); el reloj rueda como un marcador mecánico; el dock tiene magnificación y
rebote al abrir apps; los botones, onda desde el punto de clic.
`ELAREN_ANIM_SCALE` cambia la velocidad (`0` las desactiva, `2` las hace el
doble de lentas) y Configuración → Apariencia también.

## Bloqueo y energía

Bloquear, suspender, cerrar sesión, reiniciar y apagar tienen una animación a
pantalla completa antes de ejecutarse (Esc o clic la cancelan): el candado se
cierra, la luna se mece, la mano saluda, la flecha gira o la pantalla se
apaga como un televisor de tubo. Al desbloquear, la pantalla se abre en iris
con un "Hola de nuevo". Para usarlas desde atajos, mirá
[Atajos y comandos IPC](#atajos-y-comandos-ipc).

### Pantalla de bloqueo en Plasma

Elaren trae su propia pantalla de bloqueo (`lockscreen/org.elaren.lockscreen`):
reloj grande sobre el fondo desenfocado y, al tocar una tecla, una tarjeta de
vidrio con avatar, saludo y contraseña (los puntitos rebotan y la tarjeta se
sacude si te equivocás), controles de música, suspender, cambiar de usuario,
distribución de teclado y batería.

KWin no implementa `ext-session-lock`, así que el bloqueo lo sigue haciendo
kscreenlocker: Elaren reemplaza la interfaz, y la autenticación y la
protección de la sesión siguen siendo las de Plasma.

- Activar: Configuración → Bloqueo o `scripts/lockscreen.sh install`. Rige
  desde el **próximo inicio de sesión**: define `PLASMA_DEFAULT_SHELL` solo
  para KWin con un drop-in en
  `~/.config/systemd/user/plasma-kwin_wayland.service.d/`, sin tocar
  plasmashell.
- Probar sin bloquear: "Probar" en Configuración o `scripts/lockscreen.sh test`.
- Estado: `scripts/lockscreen.sh status`. Volver a la de Plasma:
  `scripts/lockscreen.sh uninstall`.

Si alguna vez quedara trabada: Ctrl+Alt+F3, iniciá sesión y
`loginctl unlock-sessions` (con "s": sin ella desbloquearía la sesión de esa
terminal, no la gráfica).

### Bloqueo en Hyprland

En Hyprland bloquea Elaren mismo, con el protocolo seguro `ext-session-lock`,
y la contraseña se verifica con PAM (`/etc/pam.d/login`). No hace falta
instalar nada.

- Bloquea desde la barra o el lanzador, con `call power lock` y con
  `loginctl lock-session`.
- Se desbloquea **solo con tu contraseña**: `loginctl unlock-session` se
  ignora a propósito (como en hyprlock), para que ningún programa pueda
  saltearla.
- Antes de suspender (también al cerrar la tapa) bloquea y espera a que la
  pantalla esté puesta.
- Mientras está bloqueada no se recarga al cambiar archivos, y si la shell se
  relanza vuelve a bloquear.
- Si otro bloqueador (hyprlock) ya tiene el protocolo, Elaren se retira. Si
  faltan los módulos de PAM o de bloqueo de Quickshell, Configuración →
  Bloqueo lo indica.

Con hypridle, que bloquee con `loginctl lock-session` y **sin `lock_cmd`**:
Elaren ya escucha ese pedido (`lock_cmd = loginctl lock-session` armaría un
bucle).

```ini
general {
    before_sleep_cmd = loginctl lock-session
}

listener {
    timeout = 300                      # 5 minutos sin uso
    on-timeout = loginctl lock-session
}
```

Si quedara trabada, ver [Solución de problemas](#solución-de-problemas).

## Atajos y comandos IPC

Todo se controla con `qs ipc -p <ruta>/shell.qml call <destino> <función>`.
Asigná estos comandos a atajos en Configuración del sistema → Atajos (Plasma)
o con `bind` en `hyprland.conf`. `qs ipc -p <ruta>/shell.qml show` lista todo.

| Destino | Funciones | Ejemplo |
|---|---|---|
| `launcher` | `toggle`, `open`, `close` | `call launcher toggle` |
| `settings` | `toggle`, `close`, `openPage <id>` | `call settings openPage widgets` |
| `power` | `lock`, `suspend`, `logout`, `reboot`, `poweroff`, `cancel`, `preview <acción>` | `call power preview poweroff` (solo la animación) |
| `volume` | `up`, `down`, `mute`, `set <0-100>`, `get` | `call volume set 40` |
| `brightness` | `up`, `down`, `set <0-100>`, `get` | `call brightness up` |
| `screenshot` | `region`, `fullscreen`, `window`, `monitor` | `call screenshot region` |
| `gamemode` | `toggle`, `enable`, `disable`, `status` | `call gamemode toggle` |
| `visualizer` | `cycle`, `setStyle <estilo>`, `place`, `done`, `setDirection <dir>` | `call visualizer setStyle wave` |
| `lockscreen` | `install`, `uninstall`, `test`, `status` (Plasma) | `call lockscreen status` |

Páginas de `openPage`: `visualizer`, `widgets`, `appearance`, `bar`, `dock`,
`wallpaper`, `gaming`, `lockscreen`, `about`.

En Plasma conviene lanzar las capturas desde Elaren (`call screenshot …`): así
primero cierra los popups y después abre Spectacle, que si no los congela en
la foto. En Hyprland las capturas usan `grim`/`slurp` y se guardan en
`$XDG_PICTURES_DIR/Capturas` (o `~/Imágenes/Capturas`).

## Solución de problemas

| Síntoma | Qué hacer |
|---|---|
| No aparece la barra | Mirá `qs log -p <ruta>/shell.qml`; en Plasma también `journalctl --user -u app-elaren@autostart -n 80` |
| Iconos como cuadrados o letras | Falta la fuente Material Symbols Rounded (`fc-list \| grep -i "material symbols"`) |
| No se ven ventanas ni escritorios (Plasma) | Falta `python3-gi` o el bus D-Bus de sesión |
| Volumen o brillo no responden (Hyprland) | Si `call volume get` responde, faltan los `bind` de la instalación |
| La barra o el dock aparecen en el medio (Plasma con tiler) | Relanzá `run.sh`: ajusta Krohnkite al arrancar |
| Bloqueo trabado en Plasma | Ctrl+Alt+F3, iniciar sesión, `loginctl unlock-sessions`; `scripts/lockscreen.sh uninstall` vuelve a la de Plasma |

**Bloqueo trabado en Hyprland**, desde otra terminal (Ctrl+Alt+F3) e
iniciando sesión:

- **Elaren anda pero no acepta la contraseña** (por ejemplo, un cambio en
  `/etc/pam.d/login`): no se puede desbloquear desde afuera. Revisá PAM desde
  esa terminal o usá el último recurso.
- **La shell se cayó** (Hyprland muestra una pantalla de error): con
  `allow_session_lock_restore` activado, relanzá Elaren con
  `hyprctl --instance 0 dispatch exec "qs -p <ruta>/shell.qml"` y volvé a la
  sesión gráfica (Ctrl+Alt+F1 o F2); vuelve a bloquear y se desbloquea con la
  contraseña. Si no lo tenías activado, antes:
  `hyprctl --instance 0 keyword misc:allow_session_lock_restore 1`.
- **Último recurso:** `hyprctl --instance 0 dispatch exit` cierra la sesión
  de Hyprland (se pierde lo que no esté guardado).

Al reportar un error, incluí el escritorio, `quickshell --version` y las
últimas líneas de `qs log -p <ruta>/shell.qml`.

## Cómo funciona por dentro

Elaren detecta el compositor de la sesión y carga el backend que corresponde.

- **KWin**: KWin no expone ventanas ni escritorios por protocolos que
  Quickshell entienda (`ext-workspace`, `foreign-toplevel`). Por eso
  `scripts/kwin-bridge.py` carga un script en KWin (`kwin/bridge.js`) que
  envía el estado por D-Bus; las órdenes (activar, minimizar, cambiar de
  escritorio) se ejecutan como scripts de KWin de un solo uso.
- **Hyprland**: ventanas, escritorios y acciones del dock van por
  `Quickshell.Hyprland`. Como Hyprland no minimiza, Elaren mueve las ventanas
  al espacio especial `special:minimized`.
- **Iconos**: `scripts/icon-resolver.py` los resuelve a archivos según el tema
  de iconos de KDE (el proveedor `image://icon` de Quickshell dejaba iconos
  invisibles en algunas ventanas).

## Desarrollo

```bash
./scripts/run.sh    # arranca la shell; se recarga sola al guardar
./scripts/lint.sh   # qmllint sobre todos los .qml
```

Estructura:

- `shell.qml` — punto de entrada; registra módulos, servicios e IPC
- `config/` — preferencias persistentes (singleton `Config`)
- `services/` — lógica sin interfaz: audio (PipeWire), batería (UPower),
  MPRIS, ventanas y escritorios, red, clima, wallpaper, bloqueo
- `services/backends/` — integración específica por compositor (Hyprland)
- `modules/` — piezas visibles: barra, isla, lanzador, dock, escritorio,
  ajustes, energía y bloqueo
- `components/` — controles reutilizables y animaciones base (`Anim`, `CAnim`,
  `StateLayer`, `Reveal`, `RollingText`, `MaterialIcon`…)
- `theme/` — colores, tipografía, formas y curvas de movimiento (singleton `Theme`)
- `kwin/` y `scripts/` — puente con KWin y herramientas auxiliares
- `lockscreen/` y `scripts/lockscreen.sh` — pantalla de bloqueo de Plasma
  (paquete para kscreenlocker, no corre dentro de Quickshell)
- `modules/lock/`, `services/SessionLock.qml` y `scripts/logind-monitor.sh` —
  bloqueo de sesión en Hyprland
- `branding/` — identidad visual de Elaren
- `media/` — videos de demostración y sus miniaturas

## Licencia y contribuciones

Elaren es software libre bajo la
[GNU General Public License v3.0 o posterior](LICENSE) (GPL-3.0-or-later):
podés usarlo, estudiarlo, modificarlo y redistribuirlo, siempre que lo que
distribuyas también sea GPL y venga con su código fuente.

Para reportar errores o proponer cambios, abrí un issue o pull request con el
escritorio, la versión de Quickshell y los pasos para reproducir el problema.
