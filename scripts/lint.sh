#!/usr/bin/env bash
# qmllint sobre todos los .qml, con la ruta de módulos de Quickshell.
set -euo pipefail
cd "$(dirname "$0")/.."

QMLLINT=$(command -v qmllint6 || command -v qmllint || echo /usr/lib/qt6/bin/qmllint)

args=()
for dir in /usr/lib/qt6/qml/quickshell /usr/lib/x86_64-linux-gnu/qt6/qml/quickshell /usr/lib64/qt6/qml/quickshell; do
    [[ -d $dir ]] && args+=(-I "$dir")
done

find . -name '*.qml' -not -path './.git/*' -print0 | xargs -0 "$QMLLINT" "${args[@]}"
