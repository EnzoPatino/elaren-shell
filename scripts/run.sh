#!/usr/bin/env bash
# Lanza Elaren en modo desarrollo (recarga en caliente al guardar).
#
# Si skwd-wall está instalado, mientras Elaren corre su daemon pasa a modo
# standalone (dibuja el fondo con skwd-paper en vez de mandarlo al plugin de
# Plasma, que sin plasmashell no existe). Al salir se restaura.
# Desactivar con ELAREN_SKWD_STANDALONE=0.
set -u
cd "$(dirname "$0")/.."

skwd_switched=0

skwd_set_standalone() {
    systemctl --user set-environment SKWD_PLASMA_BACKEND=0
    systemctl --user restart skwd-walld.service
    skwd_switched=1
}

skwd_restore() {
    [[ $skwd_switched -eq 1 ]] || return 0
    systemctl --user unset-environment SKWD_PLASMA_BACKEND
    systemctl --user restart skwd-walld.service
    skwd_switched=0
}

if [[ ${ELAREN_SKWD_STANDALONE:-1} == 1 ]] && systemctl --user is-active -q skwd-walld.service; then
    if systemctl --user show-environment | grep -qx SKWD_PLASMA_BACKEND=0; then
        skwd_switched=1 # ya estaba en standalone (p. ej. sesión anterior): restaurar igual al salir
    else
        skwd_set_standalone
    fi
fi

trap skwd_restore EXIT

# Quickshell en segundo plano para poder reenviarle las señales y restaurar
# skwd-walld aunque nos maten con SIGTERM.
quickshell -p shell.qml "$@" &
qs_pid=$!
trap 'kill -TERM "$qs_pid" 2>/dev/null' INT TERM HUP
while kill -0 "$qs_pid" 2>/dev/null; do
    wait "$qs_pid"
done
