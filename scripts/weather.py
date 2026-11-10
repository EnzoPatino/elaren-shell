#!/usr/bin/env python3
"""Clima actual y pronóstico corto desde Open-Meteo (https://open-meteo.com).

Uso: weather.py <ciudad>
Salida (una línea JSON): {"place", "current": {...}, "daily": [...]} o {"error": "..."}
Solo se envía el nombre de la ciudad (para ubicarla) y sus coordenadas.
"""

import json
import sys
import urllib.parse
import urllib.request

UA = {"User-Agent": "Elaren shell (https://github.com/EnzoPatino/elaren-shell)"}


def get(url, params):
    req = urllib.request.Request(f"{url}?{urllib.parse.urlencode(params)}", headers=UA)
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def main():
    city = " ".join(sys.argv[1:]).strip()
    if not city:
        print(json.dumps({"error": "sin ciudad"}))
        return
    try:
        geo = get("https://geocoding-api.open-meteo.com/v1/search",
                  {"name": city, "count": 1, "language": "es", "format": "json"})
        if not geo.get("results"):
            print(json.dumps({"error": f"No encontré «{city}»"}, ensure_ascii=False))
            return
        place = geo["results"][0]
        data = get("https://api.open-meteo.com/v1/forecast", {
            "latitude": place["latitude"],
            "longitude": place["longitude"],
            "current": "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min",
            "timezone": "auto",
            "forecast_days": 4,
        })
        cur = data["current"]
        daily = data["daily"]
        print(json.dumps({
            "place": place.get("name", city),
            "country": place.get("country", ""),
            "current": {
                "temp": cur["temperature_2m"],
                "feels": cur["apparent_temperature"],
                "code": cur["weather_code"],
                "wind": cur["wind_speed_10m"],
                "humidity": cur["relative_humidity_2m"],
                "day": bool(cur["is_day"]),
            },
            "daily": [
                {"date": d, "code": c, "max": hi, "min": lo}
                for d, c, hi, lo in zip(daily["time"], daily["weather_code"],
                                        daily["temperature_2m_max"], daily["temperature_2m_min"])
            ],
        }, ensure_ascii=False))
    except Exception as e:  # red caída, API con problemas…
        print(json.dumps({"error": f"Sin conexión ({type(e).__name__})"}))


if __name__ == "__main__":
    main()
