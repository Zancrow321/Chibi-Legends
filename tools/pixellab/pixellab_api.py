"""Minimal PixelLab API client (stdlib only, Pillow for images).

The key is read from the environment variable PIXELLAB_API_KEY and never
written anywhere. Endpoints follow the official Python SDK (pixellab 1.0.5):
base https://api.pixellab.ai/v1, Bearer auth, base64 PNG images.
"""

from __future__ import annotations

import base64
import io
import json
import os
import urllib.error
import urllib.request

from PIL import Image

BASE_URL = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v1")


class PixelLabError(RuntimeError):
    pass


def _key() -> str:
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not key:
        raise PixelLabError(
            "PIXELLAB_API_KEY ist nicht gesetzt. Den Key als Umgebungsvariable der Cloud-Umgebung "
            "eintragen (nie ins Repo) und die Domain api.pixellab.ai freigeben."
        )
    return key


def b64_image(img: Image.Image) -> dict:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}


def pil_image(obj: dict) -> Image.Image:
    return Image.open(io.BytesIO(base64.b64decode(obj["base64"]))).convert("RGBA")


def _request(method: str, path: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(BASE_URL + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + _key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        raise PixelLabError(f"PixelLab {path}: HTTP {e.code}: {detail}") from None
    except urllib.error.URLError as e:
        raise PixelLabError(f"PixelLab nicht erreichbar ({e.reason}). Ist api.pixellab.ai in der Umgebung freigegeben?") from None


def balance() -> dict:
    return _request("GET", "/balance")


def inpaint(description: str, image: Image.Image, mask: Image.Image, *, seed: int = 0,
            negative: str = "", color_image: Image.Image | None = None,
            text_guidance: float = 3.0, extra_guidance: float = 3.0) -> tuple[Image.Image, float]:
    """Paint `description` into the white area of `mask` on `image`. Returns (image, usd)."""
    payload = {
        "description": description,
        "negative_description": negative,
        "image_size": {"width": image.width, "height": image.height},
        "inpainting_image": b64_image(image),
        "mask_image": b64_image(mask),
        "text_guidance_scale": text_guidance,
        "extra_guidance_scale": extra_guidance,
        "outline": "single color black outline",
        "shading": "basic shading",
        "detail": "medium detail",
        "view": "side",
        "direction": "east",
        "no_background": True,
        "seed": seed,
    }
    if color_image is not None:
        payload["color_image"] = b64_image(color_image)
    out = _request("POST", "/inpaint", payload)
    return pil_image(out["image"]), float(out.get("usage", {}).get("usd", 0.0))
