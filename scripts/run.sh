#!/usr/bin/env bash
# Lanza Elaren en modo desarrollo (recarga en caliente al guardar).
exec quickshell -p "$(dirname "$0")/../shell.qml" "$@"
