#!/usr/bin/env python3
"""Imprime el wallpaper que Plasma muestra en cada salida, como "SALIDA\tRUTA".

Solo mira los escritorios que usan el plugin de skwd-wall
(wallpaperplugin=org.skwd.wall.plasma). skwd-walld guarda su propio estado
aparte y puede no coincidir con lo que Plasma está mostrando (p. ej. si al
arrancar no pudo hablar con plasmashell); este script lee la fuente de verdad
para que scripts/run.sh pueda volver a aplicarlo al pasar a standalone.
"""
import json
import os
import re
import sys

APPLETSRC = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
PLUGIN = "org.skwd.wall.plasma"


def main() -> int:
    try:
        with open(APPLETSRC, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return 1

    # Formato KConfig: secciones [A][B][C] y líneas clave=valor (sin interpolación).
    sections: dict[str, dict[str, str]] = {}
    current = None
    for line in text.splitlines():
        if line.startswith("["):
            current = line.strip()
            sections.setdefault(current, {})
        elif current and "=" in line:
            key, _, value = line.partition("=")
            sections[current][key] = value

    found: dict[str, str] = {}
    for name, keys in sections.items():
        m = re.fullmatch(r"\[Containments\]\[(\d+)\]", name)
        if not m or keys.get("wallpaperplugin") != PLUGIN:
            continue
        raw = sections.get(f"[Containments][{m[1]}][Wallpaper][{PLUGIN}][General]", {}).get("Assignments")
        if not raw:
            continue
        try:
            assignments = json.loads(raw)
        except json.JSONDecodeError:
            continue
        for output, data in assignments.items():
            path = (data.get("wallpaper") or {}).get("path") \
                or ((data.get("assignment") or {}).get("source") or {}).get("path")
            if path and os.path.exists(path):
                found.setdefault(output, path)

    for output, path in found.items():
        print(f"{output}\t{path}")
    return 0 if found else 1


if __name__ == "__main__":
    sys.exit(main())
