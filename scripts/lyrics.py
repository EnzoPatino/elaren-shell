#!/usr/bin/env python3
"""Busca la letra de un tema en LRCLIB (https://lrclib.net), con caché local.

Uso: lyrics.py <título> <artista> <álbum> <duración_en_segundos>
Salida (una línea JSON):
  {"synced": true,  "lines": [{"time": 12.3, "text": "..."}, ...]}
  {"synced": false, "lines": [{"time": -1,   "text": "..."}, ...]}
  {"synced": false, "lines": []}                       # sin letra

Los títulos de YouTube suelen traer ruido ("(Official Video)", "Artista -
Tema", canal "Artista - Topic"); se limpian antes de buscar.
"""

import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
USER_AGENT = "Elaren shell (https://github.com/EnzoPatino/elaren-shell)"
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "elaren", "lyrics")

NOISE = re.compile(
    r"\s*[\(\[](?:[^)\]]*(?:official|video|audio|lyrics?|letra|visualizer|music|hd|4k|remaster)[^)\]]*)[\)\]]",
    re.IGNORECASE,
)
LRC_LINE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)")


def clean(title, artist):
    title = NOISE.sub("", title).strip()
    artist = re.sub(r"\s*-\s*Topic$", "", artist or "").strip()
    # "Artista - Tema" en el título (típico de YouTube)
    if " - " in title:
        left, right = title.split(" - ", 1)
        if not artist or artist.lower() in left.lower() or left.lower() in artist.lower():
            artist, title = left.strip(), right.strip()
    title = re.sub(r"\s*(ft\.?|feat\.?)\s.*$", "", title, flags=re.IGNORECASE).strip()
    return title, artist


def request(path, params):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            return json.load(response)
    except Exception:
        return None


def parse(record):
    if record and record.get("syncedLyrics"):
        lines = []
        for raw in record["syncedLyrics"].splitlines():
            match = LRC_LINE.match(raw.strip())
            if match:
                minutes, seconds, text = match.groups()
                lines.append({"time": int(minutes) * 60 + float(seconds), "text": text.strip()})
        return {"synced": True, "lines": lines}
    if record and record.get("plainLyrics"):
        return {"synced": False, "lines": [{"time": -1, "text": l} for l in record["plainLyrics"].splitlines()]}
    return {"synced": False, "lines": []}


def find(title, artist, album, duration):
    params = {"track_name": title, "artist_name": artist}
    if album:
        params["album_name"] = album
    if duration > 0:
        params["duration"] = round(duration)
    record = request("get", params) if artist else None
    if record and (record.get("syncedLyrics") or record.get("plainLyrics")):
        return parse(record)

    # Búsqueda aproximada: se prefieren resultados sincronizados y de duración parecida.
    results = request("search", {"track_name": title, "artist_name": artist} if artist else {"q": title}) or []
    if not results:
        return parse(None)

    def rank(r):
        diff = abs((r.get("duration") or 0) - duration) if duration > 0 else 0
        return (0 if r.get("syncedLyrics") else 1, diff)

    return parse(sorted(results, key=rank)[0])


def main():
    title, artist, album, duration = (sys.argv[1:] + ["", "", "", "0"])[:4]
    title, artist = clean(title, artist)
    duration = float(duration or 0)

    key = hashlib.sha1(f"{title}|{artist}".lower().encode()).hexdigest()
    path = os.path.join(CACHE, key + ".json")
    if os.path.isfile(path):
        with open(path) as f:
            print(f.read().strip(), flush=True)
        return

    result = find(title, artist, album, duration)
    text = json.dumps(result, ensure_ascii=False)
    # Solo se cachean los aciertos (un "sin letra" puede ser un fallo de red).
    if result["lines"]:
        os.makedirs(CACHE, exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
    print(text, flush=True)


if __name__ == "__main__":
    main()
