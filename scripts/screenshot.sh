#!/usr/bin/env bash
# Capturas de pantalla en Hyprland (en Plasma Elaren usa Spectacle).
# Lo lanza services/backends/HyprlandBackend.qml; los popups de la barra
# quedan ocultos hasta que este script termina.
#
# Uso: screenshot.sh region | fullscreen | window | monitor
#
# Necesita grim (y slurp para "region"). Si están, también usa wl-copy para
# copiar la imagen y notify-send para avisar. Guarda en
# $XDG_PICTURES_DIR/Capturas (o ~/Imágenes/Capturas).
set -euo pipefail

mode=${1:-region}

need() {
    command -v "$1" >/dev/null 2>&1 && return
    echo "elaren: falta $1 para sacar capturas" >&2
    command -v notify-send >/dev/null 2>&1 \
        && notify-send -a Elaren "No se pudo capturar" "Falta instalar $1"
    exit 1
}

need grim

pictures=$(xdg-user-dir PICTURES 2>/dev/null || true)
[[ -n $pictures && $pictures != "$HOME" ]] || pictures="$HOME/Imágenes"
dir="$pictures/Capturas"
mkdir -p "$dir"
file="$dir/Captura $(date '+%Y-%m-%d %H-%M-%S').png"

case $mode in
    region)
        need slurp
        # Cancelar la selección (Esc) no es un error.
        geometry=$(slurp 2>/dev/null) || exit 0
        grim -g "$geometry" "$file"
        ;;
    fullscreen)
        grim "$file"
        ;;
    window)
        geometry=$(hyprctl -j activewindow | python3 -c '
import json, sys
w = json.load(sys.stdin)
if w.get("at") and w.get("size"):
    print("{},{} {}x{}".format(*w["at"], *w["size"]))
')
        if [[ -z $geometry ]]; then
            echo "elaren: no hay ventana activa" >&2
            exit 1
        fi
        grim -g "$geometry" "$file"
        ;;
    monitor)
        output=$(hyprctl -j monitors | python3 -c '
import json, sys
print(next((m["name"] for m in json.load(sys.stdin) if m.get("focused")), ""))
')
        if [[ -n $output ]]; then grim -o "$output" "$file"; else grim "$file"; fi
        ;;
    *)
        echo "uso: $0 region | fullscreen | window | monitor" >&2
        exit 2
        ;;
esac

command -v wl-copy >/dev/null 2>&1 && wl-copy --type image/png <"$file"
command -v notify-send >/dev/null 2>&1 \
    && notify-send -a Elaren -i "$file" "Captura guardada" "${file/#$HOME/\~}"
exit 0
