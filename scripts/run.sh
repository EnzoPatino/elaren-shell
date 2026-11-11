#!/usr/bin/env bash
# Lanza Elaren en modo desarrollo (recarga en caliente al guardar).
#
# Si skwd-wall está instalado y NO hay plasmashell, mientras Elaren corre su
# daemon pasa a modo standalone (dibuja el fondo con skwd-paper en vez de
# mandarlo al plugin de Plasma, que sin plasmashell no existe). Al salir se
# restaura. Con plasmashell corriendo el fondo lo sigue dibujando Plasma.
# Desactivar con ELAREN_SKWD_STANDALONE=0.
set -u
cd "$(dirname "$0")/.."

export MALLOC_ARENA_MAX=2
export MALLOC_TRIM_THRESHOLD_=131072
export mesa_glthread=false

skwd_switched=0

helm=$(command -v skwd-helm || echo "$HOME/.local/bin/skwd-helm")

# Lo que skwd-walld cree tener puesto en una salida.
skwd_current() {
    "$helm" current --json 2>/dev/null | python3 -c '
import json, sys
for o in json.load(sys.stdin).get("outputs", []):
    if o.get("name") == sys.argv[1]:
        print(o.get("path") or o.get("current") or "")
' "$1"
}

# Al reiniciarse, skwd-walld restaura SU último estado, que puede no ser lo que
# Plasma estaba mostrando (p. ej. si al arrancar la sesión plasmashell todavía
# no respondía). Sin esto el fondo cambia "solo" al lanzar Elaren.
skwd_keep_plasma_wallpaper() {
    local wanted=$1 output path tries
    [[ -n $wanted && -x $helm ]] || return 0
    # Esperar a que el daemon responda y haga su propia restauración.
    for ((tries = 0; tries < 50; tries++)); do
        "$helm" current --json >/dev/null 2>&1 && break
        sleep 0.1
    done
    sleep 0.5
    while IFS=$'\t' read -r output path; do
        [[ -n $output && -n $path ]] || continue
        [[ $(skwd_current "$output") == "$path" ]] && continue
        "$helm" apply "$path" -o "$output" >/dev/null 2>&1 \
            || echo "elaren: no pude restaurar el fondo de $output ($path)" >&2
    done <<<"$wanted"
}

skwd_set_standalone() {
    local wanted
    wanted=$(python3 scripts/plasma-wallpaper.py 2>/dev/null)
    systemctl --user set-environment SKWD_PLASMA_BACKEND=0
    systemctl --user restart skwd-walld.service
    skwd_switched=1
    skwd_keep_plasma_wallpaper "$wanted"
}

skwd_restore() {
    [[ $skwd_switched -eq 1 ]] || return 0
    systemctl --user unset-environment SKWD_PLASMA_BACKEND
    systemctl --user restart skwd-walld.service
    skwd_switched=0
}

# Con plasmashell corriendo (sesión de Plasma normal) el escritorio de Plasma ya
# dibuja el fondo con el plugin de skwd. Pasar skwd a standalone ahí abre una
# SEGUNDA superficie de fondo (skwd-wall-still/skwd-paper) encima del escritorio
# original: tapa el fondo real y los tilers como Krohnkite la tratan como una
# ventana más. En ese caso no se toca nada.
plasma_running() { pgrep -x plasmashell >/dev/null 2>&1; }

skwd_standalone_now() { systemctl --user show-environment | grep -qx SKWD_PLASMA_BACKEND=0; }

if [[ ${ELAREN_SKWD_STANDALONE:-1} == 1 ]] && systemctl --user is-active -q skwd-walld.service; then
    if plasma_running; then
        if skwd_standalone_now; then
            # Quedó en standalone de una sesión anterior: devolverlo a Plasma
            # dejando el fondo que Plasma ya muestra (no el que skwd recuerda).
            echo "elaren: plasmashell está corriendo, skwd-walld vuelve al backend de Plasma" >&2
            skwd_keep_plasma_wallpaper "$(python3 scripts/plasma-wallpaper.py 2>/dev/null)"
            skwd_switched=1
            skwd_restore
        fi
    elif skwd_standalone_now; then
        skwd_switched=1 # ya estaba en standalone (p. ej. sesión anterior): restaurar igual al salir
    else
        skwd_set_standalone
    fi
fi

trap skwd_restore EXIT

# ── Arranque ordenado ────────────────────────────────────────────────────────
# Al iniciar sesión, el autoarranque puede lanzar Elaren antes de que KWin y sus
# scripts terminen de inicializar. Si en ese momento hay un tiler (Krohnkite)
# activo, "acomoda" la barra y el dock como si fueran ventanas y aparecen en el
# medio de la pantalla. Por eso: 1) se asegura que Krohnkite ignore a Quickshell
# y a las superficies de fondo de skwd, y 2) se espera a que KWin responda.

kwin_ready() { busctl --user status org.kde.KWin >/dev/null 2>&1; }

# Agrega clases a la lista separada por comas sin duplicar.
merge_classes() {
    python3 -c '
import sys
current = [c.strip() for c in sys.argv[1].split(",") if c.strip()]
for c in sys.argv[2:]:
    if c not in current:
        current.append(c)
print(",".join(current))
' "$@"
}

ensure_krohnkite() {
    [[ $(kreadconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled 2>/dev/null) == true ]] || return 0
    local changed=0 ignore wanted layer
    ignore=$(kreadconfig6 --file kwinrc --group Script-krohnkite --key ignoreClass 2>/dev/null)
    wanted=$(merge_classes "$ignore" quickshell skwd-paper-v2 skwd-wall-vk skwd-wall-still)
    if [[ $wanted != "$ignore" ]]; then
        kwriteconfig6 --file kwinrc --group Script-krohnkite --key ignoreClass "$wanted"
        changed=1
    fi
    # Ventanas en mosaico en la capa normal: en la capa "debajo" (el valor por
    # defecto de Krohnkite) se mezclan con los widgets de escritorio.
    layer=$(kreadconfig6 --file kwinrc --group Script-krohnkite --key tiledWindowsLayer 2>/dev/null)
    if [[ $layer != 1 ]]; then
        kwriteconfig6 --file kwinrc --group Script-krohnkite --key tiledWindowsLayer 1
        changed=1
    fi
    if [[ $changed == 1 ]]; then
        echo "elaren: ajusté Krohnkite para que no acomode la barra ni los widgets" >&2
        busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1
        sleep 1
    fi
}

for ((tries = 0; tries < 100; tries++)); do
    kwin_ready && break
    sleep 0.2
done
ensure_krohnkite
# Un instante para que la pantalla y los scripts de KWin se asienten antes de
# crear la barra, el dock y los widgets. ELAREN_START_DELAY=0 lo desactiva.
sleep "${ELAREN_START_DELAY:-1.5}"

# Quickshell en segundo plano para poder reenviarle las señales y restaurar
# skwd-walld aunque nos maten con SIGTERM.
quickshell -p "$PWD/shell.qml" "$@" &
qs_pid=$!
trap 'kill -TERM "$qs_pid" 2>/dev/null' INT TERM HUP
while kill -0 "$qs_pid" 2>/dev/null; do
    wait "$qs_pid"
done
