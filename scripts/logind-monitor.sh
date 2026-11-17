#!/usr/bin/env bash
# Para services/SessionLock.qml: imprime "session <ruta>" con la ruta real de
# la sesión (p. ej. /org/freedesktop/login1/session/_32; logind emite Lock y
# Unlock desde ahí, no desde ".../session/auto") y después todas las señales
# de logind, para ver también PrepareForSleep del Manager.
set -euo pipefail

manager() {
    busctl --system call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager "$@" 2>/dev/null | awk '{ print $2 }' | tr -d '"'
}

# Primero "auto": es la misma sesión que usa SessionLock.qml para
# LockedHint, y sirve aunque Quickshell corra desde una unidad de systemd
# (como con uwsm). Si no, por XDG_SESSION_ID y por último por PID.
session=$(manager GetSession s auto || true)
if [[ -z $session && -n ${XDG_SESSION_ID:-} ]]; then
    session=$(manager GetSession s "$XDG_SESSION_ID" || true)
fi
[[ -n $session ]] || session=$(manager GetSessionByPID u $$ || true)
if [[ -z $session ]]; then
    echo "elaren: no encontré la sesión de logind" >&2
    exit 1
fi

echo "session $session"
exec gdbus monitor --system --dest org.freedesktop.login1
