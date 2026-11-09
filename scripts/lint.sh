#!/usr/bin/env bash
cd "$(dirname "$0")/.." && find . -name '*.qml' -not -path './.git/*' -print0 | xargs -0 /usr/lib/qt6/bin/qmllint
