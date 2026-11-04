"""Kleiner Client für die PixelLab REST v2 (stdlib + Pillow).

Key nur aus der Umgebungsvariable PIXELLAB_API_KEY, wird nie gespeichert.
Lange Aufträge kommen als Background-Job zurück und werden hier abgefragt.
"""
from __future__ import annotations

import base64
import io
import json
import os
import time
import urllib.error
import urllib.request

from PIL import Image

BASE_URL = os.environ.get("PIXELLAB_V2_URL", "https://api.pixellab.ai/v2")


class PixelLabError(RuntimeError):
    pass


def _key() -> str:
    key = os.environ.get("PIXELLAB_API_KEY", "").strip().strip('"')
    if not key:
        raise PixelLabError("PIXELLAB_API_KEY ist nicht gesetzt.")
    return key


def b64(img: Image.Image) -> dict:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}


def to_image(obj) -> Image.Image:
    if isinstance(obj, dict):
        if "base64" in obj:
            data = obj["base64"]
        elif "url" in obj:
            with urllib.request.urlopen(obj["url"], timeout=120) as r:
                return Image.open(io.BytesIO(r.read())).convert("RGBA")
        else:
            raise PixelLabError(f"Unbekanntes Bildformat: {list(obj)}")
    else:
        data = obj
    if isinstance(data, str) and data.startswith("data:"):
        data = data.split(",", 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA")


def request(method: str, path: str, payload: dict | None = None, timeout: int = 300) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(BASE_URL + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + _key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        raise PixelLabError(f"{path}: HTTP {e.code}: {e.read().decode(errors='replace')[:800]}") from None


def wait_job(resp: dict, poll: float = 4.0, limit: float = 900.0) -> dict:
    """Gibt das fertige Ergebnis zurück, auch wenn die API einen Job liefert."""
    job_id = resp.get("background_job_id") or (resp.get("data") or {}).get("background_job_id") if isinstance(resp, dict) else None
    if not job_id:
        return resp
    start = time.time()
    while time.time() - start < limit:
        time.sleep(poll)
        st = request("GET", f"/background-jobs/{job_id}")
        status = st.get("status") or (st.get("data") or {}).get("status")
        if status in ("completed", "succeeded", "done"):
            return st
        if status in ("failed", "error", "cancelled"):
            raise PixelLabError(f"Job {job_id} fehlgeschlagen: {json.dumps(st)[:800]}")
    raise PixelLabError(f"Job {job_id} hat zu lange gedauert")


def find_images(obj) -> list[Image.Image]:
    """Sucht alle Bilder in einer Antwort (Reihenfolge bleibt erhalten)."""
    out: list[Image.Image] = []

    def walk(o):
        if isinstance(o, dict):
            if "base64" in o and isinstance(o["base64"], str) and len(o["base64"]) > 100:
                out.append(to_image(o))
                return
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    walk(obj)
    return out
