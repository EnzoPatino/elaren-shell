# Instalar y actualizar Elaren (guía para agentes de IA)

Pasos para que un agente instale Elaren en una máquina, lo verifique y lo
actualice cuando hay cambios nuevos. Están pensados para ejecutarse en orden.
Si un paso falla, frená y contale a la persona qué salida dio; no improvises
arreglos sobre el sistema.

Reglas antes de empezar:

- **Pedí permiso** antes de cualquier cosa con `sudo` (instalar paquetes) y
  antes de editar archivos fuera del repo (`hyprland.conf`, autoarranque).
  Antes de editar un archivo de configuración, hacé una copia con fecha.
- **No toques** `~/.config/elaren/settings.json`: son las preferencias de la
  persona. Elaren lo crea solo si no existe.
- **No hagas `commit` ni `push`** si la persona no lo pidió.
- La interfaz y los comentarios del proyecto van en español rioplatense (ver
  `AGENTS.md`).

En toda la guía, `<ruta>` es la ruta absoluta del repo (por ejemplo
`~/proyectos/elaren-shell`). Tiene que ser permanente: el autoarranque, los
atajos y la pantalla de bloqueo de Plasma apuntan ahí.

---

## 1. Detectar el entorno

```bash
echo "escritorio=$XDG_CURRENT_DESKTOP sesion=$XDG_SESSION_TYPE hyprland=${HYPRLAND_INSTANCE_SIGNATURE:+si}"
command -v quickshell qs git python3 busctl gdbus
quickshell --version
```

- Elaren solo funciona en **Wayland**, con **KDE Plasma 6** o **Hyprland**.
  Con otro escritorio, frená y avisá.
- `hyprland=si` → seguí los pasos marcados **Hyprland**; si no, **Plasma**.

## 2. Dependencias

Obligatorias: Quickshell (Qt 6), Git, Python 3, Bash y la fuente
**Material Symbols** (iconos).

```bash
quickshell --version                      # tiene que responder
fc-list | grep -i "material symbols"      # tiene que listar al menos una
python3 -c "import gi" && echo "python3-gi ok"   # Plasma: integración con KWin
```

En Debian, Ubuntu y PikaOS los paquetes son `quickshell`, `git`, `python3` y
`python3-gi`. En otras distribuciones el nombre puede cambiar: buscalo con el
gestor de paquetes antes de proponerlo. Si falta la fuente, ofrecé instalarla
(Material Symbols Rounded u Outlined, de Google Fonts).

Hyprland, además, revisá:

```bash
command -v hyprctl busctl gdbus systemd-inhibit
command -v grim slurp wl-copy notify-send   # opcionales: capturas y avisos
```

Quickshell tiene que traer los módulos de Hyprland, PAM y bloqueo de sesión.
Para comprobarlo, cargá este archivo de prueba (no toca nada del sistema):

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

Opcionales (preguntá si las quiere): `cava` (espectro de audio más preciso) y
`gamemode` (modo gaming automático al abrir juegos).

## 3. Obtener el código

```bash
git clone https://github.com/EnzoPatino/elaren-shell.git <ruta>
cd <ruta>
git status
```

Si `<ruta>` ya existe, no la borres: pasá a [Actualizar](#6-actualizar).

## 4. Primer arranque y verificación

```bash
cd <ruta>
./scripts/run.sh
```

Corre en primer plano. Desde otra terminal:

```bash
qs ipc -p <ruta>/shell.qml show | head     # lista los comandos de Elaren
qs ipc -p <ruta>/shell.qml call volume get  # un número del 0 al 100
qs log -p <ruta>/shell.qml | tail -40       # registro de Elaren
```

Si `show` responde, Elaren está corriendo. En el registro no tiene que haber
líneas `ERROR`; los `WARN` de iconos SVG o de `mesa_glthread` no importan.
Para cerrarla, `Ctrl+C` en la terminal de `run.sh`.

## 5. Arranque automático

### Plasma

Crear `~/.config/autostart/elaren.desktop`:

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

Plasma lo lanza como la unidad `app-elaren@autostart.service`.

Pantalla de bloqueo de Elaren en Plasma (opcional, preguntá):

```bash
./scripts/lockscreen.sh install   # rige desde el próximo inicio de sesión
./scripts/lockscreen.sh status    # pending → falta cerrar y abrir sesión
```

### Hyprland

Hacé una copia de `~/.config/hypr/hyprland.conf` y agregale:

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

- Si ya hay un bloque `misc { … }`, agregá la línea adentro de ese bloque en
  vez de crear otro.
- Si ya hay `bind` para esas teclas (con `wpctl` o `brightnessctl`),
  comentalos: si no, cada tecla actúa dos veces.
- Si usa hypridle, su configuración **no** debe tener `lock_cmd` con hyprlock.
  Elaren bloquea por su cuenta y los dos bloqueadores se pelean.
- Aplicar sin reiniciar sesión: `hyprctl reload`.

## 6. Actualizar

Flujo habitual: la persona hace cambios en su máquina de desarrollo y los sube
a GitHub. En cada máquina donde está instalado:

```bash
cd <ruta>
git status --short          # si hay cambios locales, frená y preguntá
git pull --ff-only
```

- **Recarga en caliente:** Elaren vigila sus archivos y se recarga sola al
  cambiar un `.qml`. Mientras la sesión está bloqueada no recarga y espera al
  desbloqueo.
- **Reiniciar del todo** (cambios en `scripts/run.sh` o en variables de
  entorno, o si la recarga quedó mal):
  - Plasma: `systemctl --user restart app-elaren@autostart.service`
  - Hyprland: `pkill -f "quickshell -p <ruta>/shell.qml"` y después
    `hyprctl dispatch exec <ruta>/scripts/run.sh`
- **Pantalla de bloqueo de Plasma:** está enlazada al repo, así que el próximo
  bloqueo ya usa la versión nueva. Si el commit cambió `scripts/lockscreen.sh`,
  corré `./scripts/lockscreen.sh install` otra vez.
- **Hyprland:** si el README cambió el bloque de `hyprland.conf`, aplicá la
  diferencia a mano y corré `hyprctl reload`.

Verificá como en el paso 4 (`qs ipc … show` y el registro).

Si `git pull --ff-only` falla porque las ramas divergieron, no hagas `reset`
ni `merge` por tu cuenta: mostrale `git log --oneline -5 HEAD origin/main` a
la persona y preguntá.

### En la máquina de desarrollo, antes de subir cambios

```bash
./scripts/lint.sh                 # sin errores nuevos
git status && git diff --stat
```

Commit y push solo si la persona lo pide (ver `AGENTS.md`).

## 7. Volver a una versión anterior

```bash
cd <ruta>
git log --oneline -10
git checkout <commit>      # prueba temporal; para volver: git checkout main
```

Elaren se recarga sola con la versión elegida.

## 8. Diagnóstico

| Síntoma | Qué mirar |
|---|---|
| No aparece la barra | `qs log -p <ruta>/shell.qml`, o `journalctl --user -u app-elaren@autostart -n 80` en Plasma |
| Brillo o volumen no responden (Hyprland) | `qs ipc -p <ruta>/shell.qml call brightness get` y `… volume get`; si responden, faltan los `bind` del paso 5 |
| El bloqueo en Hyprland vuelve solo al escritorio | `qs log -p <ruta>/shell.qml \| grep -E "sessionlock\|power"` justo después de probar, y `hyprctl version \| head -3` |
| La sesión quedó bloqueada y la shell se cayó (Hyprland) | Ver README, "Bloqueo en Hyprland" |
