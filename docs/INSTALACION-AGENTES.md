# Instalar y mantener Elaren (manual para agentes de IA)

Este manual es para un agente de IA (Claude Code, Codex u otro con acceso a
una terminal) al que una persona le pidió instalar, verificar, actualizar o
desinstalar Elaren en su máquina. Los pasos están pensados para ejecutarse en
orden. Si un paso falla, frená, mostrale a la persona la salida y explicale
qué pasó: no improvises arreglos sobre el sistema.

## Reglas

- **Pedí permiso** antes de usar `sudo` (instalar paquetes) y antes de editar
  cualquier archivo fuera del repo (`hyprland.conf`, `hypridle.conf`,
  autoarranque, atajos). Antes de editar un archivo de configuración, hacé una
  copia con fecha: `cp archivo archivo.bak-$(date +%Y%m%d-%H%M%S)`.
- **No toques** `~/.config/elaren/settings.json`: son las preferencias de la
  persona. Elaren lo crea solo si no existe.
- **No borres** el repo ni carpetas existentes sin confirmación explícita.
- **No hagas `commit`, `push`, `reset` ni `merge`** si la persona no lo pidió.
- **No bloquees la sesión** para probar sin avisar antes: la persona tiene que
  saber su contraseña y estar frente a la pantalla.
- Hablale a la persona en su idioma. Si vas a modificar el código, la interfaz
  y los comentarios del proyecto van en español rioplatense.

En todo el manual, `<ruta>` es la ruta absoluta del repo (por ejemplo
`$HOME/elaren-shell`). Tiene que ser permanente: el autoarranque, los atajos y
la pantalla de bloqueo de Plasma apuntan ahí. Reemplazala siempre por la ruta
real; no dejes `<ruta>` escrito en archivos de configuración.

## Índice

0. [Preguntas iniciales](#0-preguntas-iniciales)
1. [Detectar el entorno](#1-detectar-el-entorno)
2. [Dependencias](#2-dependencias)
3. [Obtener el código](#3-obtener-el-código)
4. [Primer arranque y verificación](#4-primer-arranque-y-verificación)
5. [Arranque automático y atajos](#5-arranque-automático-y-atajos)
6. [Actualizar](#6-actualizar)
7. [Volver a una versión anterior](#7-volver-a-una-versión-anterior)
8. [Desinstalar](#8-desinstalar)
9. [Diagnóstico](#9-diagnóstico)
10. [Informe final](#10-informe-final)

---

## 0. Preguntas iniciales

Antes de ejecutar nada, confirmá con la persona (en un solo mensaje):

1. **Qué quiere hacer**: instalar, actualizar, volver a una versión anterior o
   desinstalar. Si ya existe una carpeta con Elaren, probablemente sea
   actualizar.
2. **Dónde** dejar el repo (proponé `$HOME/elaren-shell` si no tiene
   preferencia).
3. **Opcionales**: arranque automático (recomendado), pantalla de bloqueo de
   Elaren en Plasma, `cava` (espectro de audio) y `gamemode` (modo gaming
   automático).

## 1. Detectar el entorno

```bash
echo "escritorio=$XDG_CURRENT_DESKTOP sesion=$XDG_SESSION_TYPE hyprland=${HYPRLAND_INSTANCE_SIGNATURE:+si}"
command -v quickshell qs git python3 busctl gdbus
quickshell --version
cat /etc/os-release | head -3
```

- Elaren solo funciona en **Wayland**, con **KDE Plasma 6** o **Hyprland**.
  Con X11 u otro escritorio, frená y avisá.
- `hyprland=si` → seguí los pasos marcados **Hyprland**; si no, **Plasma**.
- Si estás en una sesión SSH o sin `WAYLAND_DISPLAY`, no vas a poder ver ni
  probar la shell: avisá y pedí que te ejecuten desde la sesión gráfica.

## 2. Dependencias

Obligatorias: Quickshell (Qt 6), Git, Python 3, Bash y la fuente
**Material Symbols Rounded**. En Plasma, además, `python3-gi`.

```bash
quickshell --version                              # tiene que responder
fc-list | grep -i "material symbols"              # tiene que listar al menos una
python3 -c "import gi" && echo "python3-gi ok"    # solo Plasma
```

Nombres de paquetes habituales (verificalos con el gestor antes de
proponerlos; pueden cambiar):

| Distribución | Paquetes |
|---|---|
| Debian, Ubuntu, PikaOS | `quickshell git python3 python3-gi` |
| Arch y derivadas | `quickshell` (o `quickshell-git` del AUR), `git python python-gobject` |
| Fedora | Quickshell desde un repositorio COPR; `git python3 python3-gobject` |

Si Quickshell no está empaquetado, mostrale a la persona las instrucciones de
<https://quickshell.org> en vez de compilarlo por tu cuenta.

**Fuente de iconos.** Si falta, se puede instalar sin `sudo`, solo para la
persona (pedí permiso igual, porque descarga un archivo):

```bash
mkdir -p ~/.local/share/fonts
curl -fL -o ~/.local/share/fonts/MaterialSymbolsRounded.ttf \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
fc-list | grep -i "material symbols rounded"
```

**Hyprland**, además:

```bash
command -v hyprctl busctl gdbus systemd-inhibit
command -v grim slurp wl-copy notify-send   # opcionales: capturas y avisos
```

Quickshell tiene que traer los módulos de Hyprland, PAM y bloqueo de sesión.
Comprobalo con este archivo de prueba (no toca nada del sistema):

```bash
dir=$(mktemp -d)
cat > "$dir/shell.qml" <<'EOF'
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Hyprland
ShellRoot { Component.onCompleted: { console.log("MODULOS OK"); Qt.quit() } }
EOF
timeout 10 quickshell -p "$dir/shell.qml" 2>&1 | grep -E "MODULOS OK|rror"
rm -r "$dir"
```

Si no aparece `MODULOS OK`, esa compilación de Quickshell no sirve para
Hyprland. Frená y avisá.

**Opcionales** (solo si la persona los quiso en el paso 0): `cava` y
`gamemode`.

## 3. Obtener el código

```bash
git clone https://github.com/EnzoPatino/elaren-shell.git <ruta>
cd <ruta>
git status
```

Si `<ruta>` ya existe, no la borres ni la sobrescribas: pasá a
[Actualizar](#6-actualizar).

## 4. Primer arranque y verificación

Si ya hay otra instancia de Elaren corriendo, no lances una segunda:

```bash
pgrep -af "quickshell -p .*shell.qml"
```

Arrancala en primer plano (en una terminal de la sesión gráfica, o en segundo
plano si tu herramienta lo permite):

```bash
cd <ruta>
./scripts/run.sh
```

Desde otra terminal, unos segundos después:

```bash
qs ipc -p <ruta>/shell.qml show | head      # lista los comandos de Elaren
qs ipc -p <ruta>/shell.qml call volume get  # un número del 0 al 100
qs log -p <ruta>/shell.qml | tail -40       # registro de Elaren
```

- Si `show` responde, Elaren está corriendo.
- En el registro no tiene que haber líneas `ERROR`. Los `WARN` de iconos SVG o
  de `mesa_glthread` no importan.
- Pedile a la persona que confirme que ve la barra arriba y el dock abajo, y
  que los iconos no son cuadrados (si lo son, falta la fuente).

Para cerrarla: `Ctrl+C` en la terminal de `run.sh`, o
`pkill -f "quickshell -p <ruta>/shell.qml"`.

## 5. Arranque automático y atajos

### Plasma

Crear `~/.config/autostart/elaren.desktop` (con la ruta real):

```ini
[Desktop Entry]
Type=Application
Name=Elaren
Comment=Shell de escritorio para Plasma 6 (Quickshell)
Exec=<ruta>/scripts/run.sh
Icon=quickshell
Terminal=false
X-KDE-autostart-after=panel
X-KDE-autostart-phase=2
OnlyShowIn=KDE;
```

Plasma lo lanza como la unidad `app-elaren@autostart.service`. Si la persona
ya tenía Elaren corriendo a mano, cerrá esa instancia y arrancala con
`systemctl --user start app-elaren@autostart.service` para que quede igual
que en el próximo inicio de sesión.

**Atajos.** No edites `kglobalshortcutsrc` a mano. Pasale a la persona estos
comandos para que los asigne en Configuración del sistema → Atajos → Añadir
comando:

| Acción | Comando sugerido | Tecla sugerida |
|---|---|---|
| Lanzador | `qs ipc -p <ruta>/shell.qml call launcher toggle` | Meta |
| Bloquear con animación | `qs ipc -p <ruta>/shell.qml call power lock` | Meta+L (quitarla del bloqueo de Plasma) |
| Captura de región | `qs ipc -p <ruta>/shell.qml call screenshot region` | Impr Pant (quitarla de Spectacle) |
| Modo gaming | `qs ipc -p <ruta>/shell.qml call gamemode toggle` | a elección |

**Pantalla de bloqueo de Elaren** (solo si la persona la quiso):

```bash
./scripts/lockscreen.sh test      # vista previa; se cierra con la contraseña
./scripts/lockscreen.sh install   # rige desde el próximo inicio de sesión
./scripts/lockscreen.sh status    # pending → falta cerrar y abrir sesión
```

Avisale que, si quedara trabada, desde Ctrl+Alt+F3 se sale con
`loginctl unlock-sessions` y se revierte con `./scripts/lockscreen.sh uninstall`.

### Hyprland

Hacé una copia de `~/.config/hypr/hyprland.conf` y agregale (con la ruta
real):

```ini
exec-once = <ruta>/scripts/run.sh

misc {
    allow_session_lock_restore = true
}

$elaren = qs ipc -p <ruta>/shell.qml call
bindel = , XF86AudioRaiseVolume, exec, $elaren volume up
bindel = , XF86AudioLowerVolume, exec, $elaren volume down
bindl  = , XF86AudioMute, exec, $elaren volume mute
bindel = , XF86MonBrightnessUp, exec, $elaren brightness up
bindel = , XF86MonBrightnessDown, exec, $elaren brightness down
```

Antes de agregar, revisá lo que ya hay:

```bash
grep -nE "exec-once|^misc|XF86Audio|XF86MonBrightness|hyprlock|SUPER, *(SPACE|L)|Print" ~/.config/hypr/hyprland.conf
grep -rn "source" ~/.config/hypr/hyprland.conf    # la config puede estar repartida
```

- Si ya hay un bloque `misc { … }`, agregá la línea adentro de ese bloque.
- Si ya hay `bind` para esas teclas (con `wpctl` o `brightnessctl`),
  comentalos: si no, cada tecla actúa dos veces.
- Si hay `exec-once` de otra barra (waybar, eww, otra shell de Quickshell),
  preguntá si la quiere desactivar: dos barras se superponen.
- Atajos opcionales, solo si la persona los quiere y no pisan otros:

  ```ini
  bind = SUPER, SPACE, exec, $elaren launcher toggle
  bind = SUPER, L, exec, $elaren power lock
  bind = , Print, exec, $elaren screenshot region
  ```

**hypridle.** Si existe `~/.config/hypr/hypridle.conf`:

```bash
grep -nE "lock_cmd|before_sleep_cmd|on-timeout" ~/.config/hypr/hypridle.conf
```

No debe tener `lock_cmd` con hyprlock ni con `loginctl lock-session` (Elaren
bloquea por su cuenta y los dos se pelean o arman un bucle). Proponé dejarlo
así, con copia previa:

```ini
general {
    before_sleep_cmd = loginctl lock-session
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}
```

Aplicar sin reiniciar la sesión: `hyprctl reload` (y
`systemctl --user restart hypridle` o relanzar hypridle si lo cambiaste).
Verificá que las teclas pasan por Elaren:

```bash
qs ipc -p <ruta>/shell.qml call volume get
qs ipc -p <ruta>/shell.qml call brightness get   # en equipos sin pantalla interna puede no haber brillo
```

Probar el bloqueo solo con aviso previo: `qs ipc -p <ruta>/shell.qml call power lock`.

## 6. Actualizar

```bash
cd <ruta>
git status --short          # si hay cambios locales, frená y preguntá
git fetch
git log --oneline HEAD..origin/main   # qué trae la actualización
git pull --ff-only
```

- **Recarga en caliente:** Elaren vigila sus archivos y se recarga sola al
  cambiar un `.qml`. Con la sesión bloqueada no recarga y espera al
  desbloqueo.
- **Reiniciar del todo** (si cambió `scripts/run.sh`, variables de entorno, o
  la recarga quedó mal):
  - Plasma: `systemctl --user restart app-elaren@autostart.service`
  - Hyprland: `pkill -f "quickshell -p <ruta>/shell.qml"` y después
    `hyprctl dispatch exec <ruta>/scripts/run.sh`
- **Pantalla de bloqueo de Plasma:** está enlazada al repo, así que el
  próximo bloqueo ya usa la versión nueva. Si cambió `scripts/lockscreen.sh`,
  corré `./scripts/lockscreen.sh install` otra vez.
- **Hyprland:** si cambió el bloque de `hyprland.conf` del README
  (`git diff HEAD@{1} -- README.md`), aplicá la diferencia con copia previa y
  corré `hyprctl reload`.

Verificá como en el paso 4.

Si `git pull --ff-only` falla porque las ramas divergieron, no hagas `reset`
ni `merge` por tu cuenta: mostrale `git log --oneline -5 HEAD origin/main` a
la persona y preguntá.

### En la máquina de desarrollo, antes de subir cambios

```bash
./scripts/lint.sh                 # sin errores nuevos
git status && git diff --stat
```

Commit y push solo si la persona lo pide.

## 7. Volver a una versión anterior

```bash
cd <ruta>
git log --oneline -10
git checkout <commit>      # prueba temporal
git checkout main          # para volver a la última
```

Elaren se recarga sola con la versión elegida. Avisale a la persona que, en
esa versión, `git pull` no actualiza hasta volver a `main`.

## 8. Desinstalar

Confirmá cada punto con la persona antes de borrar.

1. **Plasma, pantalla de bloqueo** (si estaba instalada):
   `./scripts/lockscreen.sh uninstall` y `./scripts/lockscreen.sh status`.
2. **Detener Elaren:** `pkill -f "quickshell -p <ruta>/shell.qml"`.
3. **Arranque automático:**
   - Plasma: borrar `~/.config/autostart/elaren.desktop`.
   - Hyprland: con copia previa, quitar de `hyprland.conf` el `exec-once`, el
     `$elaren` y sus `bind` (restaurar los `bind` con `wpctl`/`brightnessctl`
     si se habían comentado) y correr `hyprctl reload`.
4. **Atajos de Plasma:** pedile a la persona que borre los comandos
   personalizados en Configuración del sistema → Atajos.
5. **Repo:** borrar `<ruta>` solo con confirmación.
6. **Datos** (preguntá; son de la persona): `~/.config/elaren/` (preferencias)
   y `~/.cache/elaren/` (letras en caché).

## 9. Diagnóstico

| Síntoma | Qué mirar |
|---|---|
| No aparece la barra | `qs log -p <ruta>/shell.qml`; en Plasma, `journalctl --user -u app-elaren@autostart -n 80` |
| `qs ipc … show` no responde | Elaren no está corriendo: `pgrep -af quickshell`; lanzá `run.sh` en primer plano y leé el error |
| Iconos como cuadrados o letras | Falta la fuente: paso 2 |
| No hay ventanas ni escritorios en la barra (Plasma) | `python3 -c "import gi"` y `busctl --user status org.kde.KWin` |
| Barra o dock en el medio de la pantalla (Plasma con Krohnkite) | Reiniciar Elaren: `run.sh` ajusta Krohnkite al arrancar |
| Dos barras superpuestas | Otra barra en el autoarranque (waybar, otra shell de Quickshell) |
| Brillo o volumen no responden (Hyprland) | `call brightness get` y `call volume get`; si responden, faltan o están pisados los `bind` del paso 5 |
| El bloqueo en Hyprland vuelve solo al escritorio | `qs log -p <ruta>/shell.qml \| grep -E "sessionlock\|power"` justo después de probar; ¿hay hyprlock corriendo? (`pgrep -a hyprlock`) |
| La sesión quedó bloqueada y la shell se cayó (Hyprland) | README, sección "Solución de problemas" |
| Bloqueo de Plasma trabado | Ctrl+Alt+F3, `loginctl unlock-sessions`, `./scripts/lockscreen.sh uninstall` |

## 10. Informe final

Al terminar, dale a la persona un resumen corto con:

- Qué hiciste (instalación, actualización, desinstalación) y en qué `<ruta>`.
- Qué paquetes instalaste y qué archivos de configuración tocaste, con la ruta
  de cada copia de respaldo.
- Qué verificaste y con qué resultado (salida de `show`, errores del log).
- Qué quedó pendiente para ella: cerrar y abrir sesión (pantalla de bloqueo
  de Plasma), asignar atajos, instalar algo que no quiso.
- Cómo deshacerlo: [Desinstalar](#8-desinstalar).
