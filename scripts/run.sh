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

# Quickshell en segundo plano para poder reenviarle las señales y restaurar
# skwd-walld aunque nos maten con SIGTERM.
quickshell -p "$PWD/shell.qml" "$@" &
qs_pid=$!
trap 'kill -TERM "$qs_pid" 2>/dev/null' INT TERM HUP
while kill -0 "$qs_pid" 2>/dev/null; do
    wait "$qs_pid"
done
