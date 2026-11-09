#!/usr/bin/env python3
"""Resuelve nombres de iconos a archivos según el tema de iconos de KDE.

Elaren no usa el proveedor `image://icon` de Quickshell porque en algunas
ventanas no dibuja los iconos (cargan "Ready" pero quedan invisibles). Las
imágenes cargadas como archivo sí funcionan siempre, así que este helper:

1. Lee el tema de ~/.config/kdeglobals ([Icons] Theme) o QS_ICON_THEME.
2. Arma la cadena de herencia (Inherits=…) terminando en hicolor.
3. Indexa una sola vez los iconos de esos temas y /usr/share/pixmaps.
4. Por cada nombre recibido por stdin (uno por línea) responde una línea JSON
   {"name": ..., "path": ... o null}, prefiriendo SVG y luego el PNG más grande.
"""

import configparser
import json
import os
import re
import sys

EXTENSIONS = (".svg", ".png", ".xpm")
HOME = os.path.expanduser("~")


def base_dirs():
    dirs = [os.path.join(HOME, ".icons"), os.path.join(HOME, ".local/share/icons")]
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    dirs += [os.path.join(d, "icons") for d in data_dirs if d]
    seen = []
    for d in dirs:
        if os.path.isdir(d) and d not in seen:
            seen.append(d)
    return seen


def current_theme():
    if os.environ.get("QS_ICON_THEME"):
        return os.environ["QS_ICON_THEME"]
    config = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        config.read(os.path.join(HOME, ".config/kdeglobals"))
        return config.get("Icons", "Theme", fallback="breeze")
    except configparser.Error:
        return "breeze"


def inherits(theme, bases):
    for base in bases:
        index = os.path.join(base, theme, "index.theme")
        if os.path.isfile(index):
            config = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                config.read(index)
                value = config.get("Icon Theme", "Inherits", fallback="")
                return [t.strip() for t in value.split(",") if t.strip()]
            except configparser.Error:
                return []
    return []


def theme_chain(theme, bases):
    chain, queue = [], [theme]
    while queue:
        t = queue.pop(0)
        if t in chain:
            continue
        chain.append(t)
        queue.extend(inherits(t, bases))
    for fallback in ("breeze", "hicolor"):
        if fallback in chain:
            chain.remove(fallback)
        chain.append(fallback)
    return chain


SIZE_RE = re.compile(r"(?:^|/)(\d+)(?:x\d+)?(?:@(\d)x)?(?:/|$)")


def score(path):
    """Mayor es mejor: SVG antes que PNG; dentro de cada tipo, el más grande."""
    match = SIZE_RE.search(path)
    size = int(match.group(1)) * int(match.group(2) or 1) if match else 0
    if path.endswith(".svg"):
        return 10_000 + (1_000 if "/scalable/" in path else size)
    return size or 1


def index_dir(root, table):
    for dirpath, _dirs, files in os.walk(root, followlinks=True):
        for file in files:
            name, ext = os.path.splitext(file)
            if ext not in EXTENSIONS:
                continue
            path = os.path.join(dirpath, file)
            best = table.get(name)
            if best is None or score(path) > score(best):
                table[name] = path


def build_index():
    bases = base_dirs()
    tables = []
    for theme in theme_chain(current_theme(), bases):
        table = {}
        for base in bases:
            root = os.path.join(base, theme)
            if os.path.isdir(root):
                index_dir(root, table)
        if table:
            tables.append(table)
    pixmaps = {}
    for root in ("/usr/share/pixmaps", os.path.join(HOME, ".local/share/pixmaps")):
        if os.path.isdir(root):
            index_dir(root, pixmaps)
    tables.append(pixmaps)
    return tables


def resolve(name, tables):
    if not name:
        return None
    if name.startswith("/"):
        return name if os.path.isfile(name) else None
    base = os.path.splitext(name)[0] if name.endswith(EXTENSIONS) else name
    for table in tables:
        if base in table:
            return table[base]
    lower = base.lower()
    for table in tables:
        for key, path in table.items():
            if key.lower() == lower:
                return path
    return None


def main():
    tables = build_index()
    for line in sys.stdin:
        name = line.strip()
        print(json.dumps({"name": name, "path": resolve(name, tables)}), flush=True)


if __name__ == "__main__":
    main()
