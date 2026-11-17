#!/usr/bin/env bash
# Pantalla de bloqueo de Elaren (lockscreen/org.elaren.lockscreen).
#
# KWin no implementa ext-session-lock, así que el bloqueo real lo sigue
# haciendo kscreenlocker (el de Plasma) y Elaren solo le cambia la interfaz.
# kscreenlocker_greet elige su paquete con la misma clave que plasmashell
# (plasmashellrc [Shell] ShellPackage) o, si no está, con PLASMA_DEFAULT_SHELL.
# Para no tocar plasmashell, esa variable se define SOLO para KWin (de quien
# hereda el entorno el greeter) con un drop-in de su unidad de systemd.
#
# Uso:
#   lockscreen.sh install     enlaza el paquete y crea el drop-in (rige desde
#                             el próximo inicio de sesión)
#   lockscreen.sh uninstall   lo deshace
#   lockscreen.sh status      off | pending (falta reiniciar sesión) | active |
#                             blocked (plasmashellrc fija ShellPackage) |
#                             unsupported (KWin no corre como unidad de
#                             systemd: el drop-in no se aplica)
#   lockscreen.sh test        abre la pantalla en modo prueba (no bloquea;
#                             se cierra escribiendo tu contraseña)
#   lockscreen.sh sync k=v…   guarda opciones en kscreenlockerrc
#
# Si algo saliera mal estando bloqueado: Ctrl+Alt+F3, iniciar sesión y
# `loginctl unlock-session`.
set -euo pipefail
cd "$(dirname "$0")/.."

readonly id=org.elaren.lockscreen
readonly package="$PWD/lockscreen/$id"
readonly data="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly config="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly link="$data/plasma/shells/$id"
readonly unit=plasma-kwin_wayland.service
readonly dropin_dir="$config/systemd/user/$unit.d"
readonly dropin="$dropin_dir/elaren-lockscreen.conf"

greeter() {
    local path
    for path in /usr/lib/x86_64-linux-gnu/libexec /usr/lib/aarch64-linux-gnu/libexec \
        /usr/libexec /usr/lib/libexec /usr/lib64/libexec; do
        if [[ -x $path/kscreenlocker_greet ]]; then
            echo "$path/kscreenlocker_greet"
            return
        fi
    done
    echo "elaren: no encontré kscreenlocker_greet" >&2
    return 1
}

shell_package_pinned() {
    [[ -n $(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null) ]]
}

cmd_install() {
    mkdir -p "$(dirname "$link")"
    if [[ -e $link && ! -L $link ]]; then
        echo "elaren: $link existe y no es un enlace de Elaren; no lo toco" >&2
        exit 1
    fi
    ln -sfn "$package" "$link"

    mkdir -p "$dropin_dir"
    cat >"$dropin" <<EOF
# Creado por Elaren (scripts/lockscreen.sh). Hace que kscreenlocker use la
# pantalla de bloqueo de Elaren; borrar este archivo la desactiva.
[Service]
Environment=PLASMA_DEFAULT_SHELL=$id
EOF
    systemctl --user daemon-reload

    if shell_package_pinned; then
        echo "elaren: plasmashellrc fija [Shell] ShellPackage y tiene prioridad;" \
            "la pantalla de Elaren no se va a usar mientras exista esa clave" >&2
    fi
    echo "elaren: listo, se usa desde el próximo inicio de sesión"
}

cmd_uninstall() {
    rm -f "$dropin"
    rmdir "$dropin_dir" 2>/dev/null || true
    systemctl --user daemon-reload
    [[ -L $link ]] && rm -f "$link"
    echo "elaren: desactivada (vuelve la de Plasma desde el próximo inicio de sesión)"
}

cmd_status() {
    if [[ ! -f $dropin || ! -L $link ]]; then
        echo off
        return
    fi
    # ShellPackage tiene prioridad sobre PLASMA_DEFAULT_SHELL: así no se usa.
    if shell_package_pinned; then
        echo blocked
        return
    fi
    # Sin la unidad de KWin activa (Hyprland, Plasma X11 o Plasma iniciado
    # sin systemd) nadie toma el drop-in.
    if ! systemctl --user is-active --quiet "$unit" 2>/dev/null; then
        echo unsupported
        return
    fi
    # ¿El KWin que corre ya tiene la variable? Se lee su entorno real, así
    # reinstalar (o apagar y prender) no confunde el estado.
    local pid
    pid=$(systemctl --user show "$unit" -p MainPID --value 2>/dev/null || true)
    if [[ -n $pid && $pid != 0 ]] \
        && grep -qzxF "PLASMA_DEFAULT_SHELL=$id" "/proc/$pid/environ" 2>/dev/null; then
        echo active
    else
        echo pending
    fi
}

cmd_test() {
    local bin tmp
    bin=$(greeter)
    # Funciona aunque no esté instalada: un XDG_DATA_DIRS temporal con el paquete.
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/plasma/shells"
    ln -s "$package" "$tmp/plasma/shells/$id"
    PLASMA_DEFAULT_SHELL=$id XDG_DATA_DIRS="$tmp:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
        "$bin" --testing
}

cmd_sync() {
    local pair
    for pair in "$@"; do
        [[ $pair == *=* ]] || continue
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General \
            --key "${pair%%=*}" "${pair#*=}"
    done
}

case "${1:-}" in
    install) cmd_install ;;
    uninstall) cmd_uninstall ;;
    status) cmd_status ;;
    test) cmd_test ;;
    sync) shift; cmd_sync "$@" ;;
    *)
        echo "uso: $0 install | uninstall | status | test | sync clave=valor…" >&2
        exit 2
        ;;
esac
