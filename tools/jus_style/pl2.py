"""Kleiner PixelLab-REST-v2-Client fuer den Stil-Test (Key nur aus PIXELLAB_API_KEY)."""
from __future__ import annotations
import base64, io, json, os, time, urllib.request, urllib.error
from PIL import Image

BASE = "https://api.pixellab.ai/v2"

def _req(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method)
    r.add_header("Authorization", "Bearer " + os.environ["PIXELLAB_API_KEY"].strip())
    if data is not None:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r, timeout=300) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{path}: HTTP {e.code}: {e.read().decode(errors='replace')[:600]}") from None

def b64(img: Image.Image) -> dict:
    buf = io.BytesIO(); img.save(buf, format="PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}

def to_img(obj) -> Image.Image:
    s = obj["base64"] if isinstance(obj, dict) else obj
    if s.startswith("data:"):
        s = s.split(",", 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(s))).convert("RGBA")

def balance():
    return _req("GET", "/balance")["subscription"]["generations"]

def post(path, payload):
    return _req("POST", path, payload)

def wait_job(job_id, every=4, limit=600):
    t0 = time.time()
    while time.time() - t0 < limit:
        j = _req("GET", f"/background-jobs/{job_id}")
        if j.get("status") in ("completed", "failed"):
            return j
        time.sleep(every)
    raise RuntimeError("job timeout")
